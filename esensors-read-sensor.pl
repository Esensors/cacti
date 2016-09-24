#!/usr/bin/env perl
#
# 
#

use strict;
use warnings;
use Getopt::Long;
use Data::Dumper;
use IO::Socket;
use Carp;

$| = 1;
$Data::Dumper::Sortkeys = 1;
                                                                  
Getopt::Long::Configure('bundling');

# copied from check_esensor.pl
# TODO: move to shared module

my $sensors = {
    'temperature'  => { 'name' => 'Temperature',  'flag' => 'sht',  'value' => 'tm0', 'uom' => 'tun0', },
    'humidity'     => { 'name' => 'Humidity',     'flag' => 'sht',  'value' => 'hu0', },
    'illumination' => { 'name' => 'Illumination', 'flag' => 'ilum', 'value' => 'il0', },
    'voltage'      => { 'name' => 'Voltage',      'flag' => 'evin', 'value' => 'vin', },
    'thermistor'   => { 'name' => 'Thermistor',   'flag' => 'ethm', 'value' => 'thm', },
    'contact'      => { 'name' => 'Contact',      'flag' => 'ecin', 'value' => 'cin', 'type' => 'boolean' },
    'flood'        => { 'name' => 'Flood',        'flag' => 'efld', 'value' => 'fin', 'type' => 'boolean' },
    };
$sensors->{'temp'} = $sensors->{'temperature'};
$sensors->{'hum'} = $sensors->{'humidity'};
$sensors->{'illum'} = $sensors->{'illumination'};
$sensors->{'light'} = $sensors->{'illumination'};

my $opt_debug = 0;
my $opt_ver = 0;
my $opt_help = 0;
my $opt_typ = '';
my $opt_host;
my $opt_port = 80;
my $opt_timeout = 15;
my $opt_dev = 0;
my $opt_test;
my $opt_device = "xml";
my $opt_url = "";

GetOptions(
    "debug|d" => \$opt_debug,
    "help|h" => \$opt_help,
    
    "host=s" => \$opt_host,
    "timeout=s" => \$opt_timeout,
    "port=s" => \$opt_port,

    "url=s" => \$opt_url,

    "sensor|type=s" => \$opt_typ,
);

if ($opt_help) {
    &syntax();
}

my $sensor_host = $opt_host || $ARGV[0] || &syntax();
if ($opt_timeout eq 'default') {
    $opt_timeout = 15;
}

if (!defined($sensors->{$opt_typ})) {
    &syntax();
}

my $vals = &read_sensor($sensor_host, $opt_timeout);
&debug(Data::Dumper::Dumper($vals));

if ($opt_device eq 'xml') {
    if (! defined($vals->{$sensors->{$opt_typ}->{'flag'}})) {
        sensor_error('UNKNOWN', "UNKNOWN: sensor [$sensors->{$opt_typ}->{'name'} ($opt_typ)] " .
            "(field $sensors->{$opt_typ}->{'flag'}) is not present on the device 1");
    }
    if ($vals->{$sensors->{$opt_typ}->{'flag'}} ne 'inline') {
        sensor_error('UNKNOWN', "UNKNOWN: sensor [$sensors->{$opt_typ}->{'name'} ($opt_typ)]: ".
            "field $sensors->{$opt_typ}->{'flag'} is [$vals->{$sensors->{$opt_typ}->{'flag'}}];" . 
            "sensor is not present on the device");
    }
    if (! defined($vals->{$sensors->{$opt_typ}->{'value'}})) {
        sensor_error('UNKNOWN', "UNKNOWN: sensor [$sensors->{$opt_typ}->{'name'} ($opt_typ)] " .
            "(field $sensors->{$opt_typ}->{'value'}) is not present on the device 2");
    }

    print $vals->{$sensors->{$opt_typ}->{'value'}} . "\n";
}

sub read_sensor {
    my ($host, $timeout) = @_;

    my $remote = IO::Socket::INET->new(
         Proto    => "tcp",
         PeerAddr => $host,
         PeerPort => $opt_port,
         Timeout  => $timeout,
    );

    if (!$remote) {
        &debug("connect error: $!\n");
        print "failed to connect\n";
        exit(1);
    }
    &debug("connected to $host:$opt_port\n");

    my $didalarm = 0;
    my $hdrs = {};
    my $read = {};
    my $remote_line_number = 0;
    my $response = "";

    eval {
        local $SIG{'ALRM'} = sub { $didalarm=1; die "alarm\n"; };
        alarm($timeout);

        if ($opt_device eq 'xml') {
            if ($opt_dev) {
                print $remote "GET " . $opt_url . " HTTP/1.1\r\nUser-Agent: EsensorsPlugin\r\nHost: $host\r\nConnection: close\r\n\r\n";
            }
            else {
                print $remote "GET " . $opt_url . " HTTP/1.1\r\nUser-Agent: EsensorsPlugin\r\nHost: $host\r\n\r\n";
            }

            # read in all the response, waiting for the sensor data end
            READ_REMOTE: while (my $l = <$remote>) {
#                print $l;
                $response .= $l;

                if ($response =~ /(<sensorsSW>.+<\/sensorsSW>)/s) {
                    $read = parse_ssetings_xml($response);
                    last READ_REMOTE;
                }
            }
        }
        else {
            if ($opt_dev) {
                print $remote "GET " . $opt_url . " HTTP/1.1\r\nUser-Agent: EsensorsPlugin\r\nHost: $host\r\nConnection: close\r\n\r\n";
            }
            else {
                # HTTP/1.1 bug found by Fabrice Duley (Fabrice.Duley@alcatel.fr)
                print $remote "GET " . $opt_url . " HTTP/1.1 \r\n";
            }
                    
            my $inhdr = 1;
            while (my $l = <$remote>) {
                $remote_line_number++;
                $response .= $l;

                if ($inhdr) {
                    $l =~ s/[\n\r]+$//;
                    if (!length($l)) {
                        $inhdr = 0;
                    }
                    elsif ($l =~ /^([^ :]+)([ :])\s*(.*)$/) {
                        my $n = lc $1;
                        my $v = $3;
                        if (!exists($hdrs->{$n})) {
                            $hdrs->{$n} = [$v];
                        } else {
                            push(@{$hdrs->{$n}}, $v);
                        }
                    }
                    else {
                        &debug("Unexpected HTTP header at line $remote_line_number: $l\n");
                    }
                }
                # https://www.monitoring-plugins.org/archive/devel/2005-May/003660.html
                # Ben Clewett ben at clewett.org.uk
                # Thu May 12 05:17:31 CEST 2005
                elsif ($l =~ /T\D*?([A-Z])\D*?([0123456789.]+)\D*?
                          HU\D*?([0123456789.]+)\D*?
                          IL\D*?([0123456789.]+)/gx)
                # http://eesensors.com/products/websensors/server-room-temperature-monitoring.html
                # SM701679TF: 80.6HU:19.7%IL 4.1
                # àM701679RF 81.1 (not implemented)
                {
                    $read->{'temp-unit'} = $1;
                    $read->{'temperature'} = $2;
                    $read->{'humidity'} = $3;
                    $read->{'illumination'} = $4;
                }
            }
        }

        close($remote);
        alarm(0);
    };

    if (defined($read->{'temp-unit'}) &&
        defined($read->{'temperature'}) &&
        defined($read->{'humidity'}) &&
        defined($read->{'illumination'}) ||
        defined($read->{'sht'})
        ) {
    
        return $read;
    }
    else {
        if ($@) {
            die $@ if $didalarm != 1;
            &debug("timeout $timeout expired during sensor read\n");
            &debug("data received from sensor: $response\n");
            print "Unable to read sensor (timeout $timeout seconds expired)\n";
            exit(1);
        }
        else {
            # https://github.com/pashol/nagios-checks
            # our sensor retunred many times no values, which ended up as critical in nagios.
            # Which in return gave a bad SLA at the end of the month. Therefore it goes into unknown now.
            #
            # https://github.com/pashol/nagios-checks/commit/31cdba775a226672207f92d2e9e5e3365ac88a54#diff-262e64bf9a35e13ebbec3d1c8ab6856b
            print "No values received from sensor\n";
            &debug("data received from sensor: $response\n");
            exit(1);
        }
    }
};

sub syntax_sensors_list {
    my ($alignment) = @_;
    my $list = "";
    my $line = "";
    foreach my $sensor (sort keys %{$sensors}) {
        $line .= $sensor . ", ";
        if (length($line) > 60) {
            $list .= $line;
            $line = "\n" . $alignment;
        }
    }
    if ($line =~ /[^\s]+/s) {
        $list .= $line;
    }
    chop($list);
    chop($list);
    return $list;
}

sub syntax {
  print qq{
Syntax:
    $0 --host <NAME> --sensor <NAME> [options]

Mandatory parameters:
  --host <NAME>
    address of device on network (name or IP).
  --sensor <NAME>
    name of the sensor; set of available sensors depends on device model;
    should be one of (note few aliases which are interchangable):
    } . syntax_sensors_list("    ") . qq{

Optional parameters:
  --port=x
    port of the device. Default=$opt_port.
  --timeout=x
    how long to wait before failing. Default=$opt_timeout.

  --debug
    print debug messages to STDERR
  --dev
    developer's mode allowing to test plugin on a standard http server
    (older devices http server did not conform to http standard)

Example:
    $0 --host sensor0 --sensor temperature

};
  exit(0);
}

sub debug {
    my ($msg) = @_;

    if ($opt_debug) {
        print STDERR $msg;
    }
};

sub parse_ssetings_xml {
    my ($xml) = @_;
    my $struct = {};

    my $tmp = $xml;
    # get all the opening tags
    if ($tmp =~ /<sensorsSW>(.+)$/s) {
        $tmp = $1;
        while ($tmp =~ /[^\<]<([a-zA-Z0-9]+)>(.+)$/s) {
            $tmp = $2;
            $struct->{$1} = "";
        }
    }
    
    # fill in the values for all the found tags
    foreach my $k (keys %{$struct}) {
        if ($xml =~ /<$k>([^\<]+)<\/$k>/) {
            $struct->{$k} = $1;
        }
    }

    return $struct;
}

sub sensor_error {
    my ($state, $msg) = @_;
    print STDERR $msg . ($msg =~ /\n$/s ? "" : "\n");
    exit(1);
}

