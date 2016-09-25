# Esensors Websensor Plugin and Templates for Cacti

  * [Esensors Websensor Plugin and Templates for Cacti](#esensors-websensor-plugin-and-templates-for-cacti)
    * [Configuring Cacti](#configuring-cacti)
      * [Plugin](#plugin)
      * [Templates](#templates)
      * [Custom Port and URL settings](#custom-port-and-url-settings)
      * [Creating graphs](#creating-graphs)
      * [Attaching websensor to Graph Tree](#attaching-websensor-to-graph-tree)
    * [Investigating issues](#investigating-issues)

## Configuring Cacti
There're two distinct entities which should downloaded and configured
in Cacti so that you could graph your device:
* the plugin itself (esensors-read-sensor.pl)
* Data, Graph and Host templates (all packaged in cacti_host_template_esensors_websensor_generic.xml)

### Plugin
Plugin file should be installed manually into Cacti scripts/ directory,
for example, if Cacti is installed into `/var/www/cacti`, then you need to put
`esensors-read-sensor.pl` into `/var/www/cacti/scripts` directory.

Please make sure that executable bit is set on the scipt.

### Templates
To configure Esensors templates in Cacti choose "Import Templates"
(found under "Import/Export" heading) in Cacti menu and either
upload the file or paste the contents of the file.

Make sure to choose "Use custom RRA settings from the template" option.

### Custom Port and URL settings
Esensors plugin comes with preconfigured Data Input Method, which uses
standard port and url settings (`80` and `/status.xml` respectively).
If your device uses different port and/or url settings, you would need
to configure it in the "Esensors Websensor - Get Sensor" Data Input Method
found under "Collection Methods" heading, "Data Input Methods" menu item.

Just replace defaults with your custom values and press "Save"
in the bottom of the screen.

### Creating graphs
Once you have installed the plugin and templates you can create graphs
for your device and start gathering statistics:
* under `Management -> Devices` choose "Add" link
* fill-in required fields
  * Description - give a meaningful description such as `My new Websensor`
  * Hostname - specify hostname or ip address of the device (make sure that device
    is accessible using the value specified from the cacti server)
  * Host Template - choose "Esensors Websensor (Generic)"
  * Downed Device Detection - choose "None"
  * SNMP Version - choose "Not In Use"
  * Push "Create" button (bottom right of the screen)

Once you've succeeded creating new device (got "Save Successful." message
at the top of the screen), continue to creating graphs by following
the "Create Graphs for this Host" link (top right of the screen).

On the "New Graphs" screen simply select those sensors which are available
in your device (you can select them by left-clicking anywhere in the line)
and push "Create" button.

You should get a bunch of "Created graph" messages at the top of the screen.

Once poller is run (might take few minutes depending on the schedule you've
configured in cron) the graphs are created and started to be populated regularly
with new data.

### Attaching websensor to Graph Tree
Although graphs become available almost immediately after their creation
they will not be available on "Graphs" tab unless you attach them to Graph tree.

The easiest way to do it is to attach them to the "Default Tree".

Go to "Console" tab (if you already switched to "Graphs"), under
`Management -> Graph Trees` choose "Default Tree", follow "Add" link
and fill-in the fields:
* Tree Item Type - Host
* Host - "My New Websensor"

Push "Create" button.

After that the host would be available under "graphs" tab

## Investigating issues
