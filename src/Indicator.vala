/*-
 * Copyright (c) 2021 Fernando Casas Schössow (https://github.com/casasfernando/wingpanel-indicator-airpods)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 3 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301 USA.
 *
 * Authored by: Fernando Casas Schössow <casasfernando@outlook.com>
 */

namespace WingpanelAirPods {
    public class Indicator : Wingpanel.Indicator {
        const string APPNAME = "wingpanel-indicator-airpods";

        private DisplayWidget display_widget;
        private PopoverWidget popover_widget;
        private WingpanelAirPods.DBusProperties airpods_conn_mon = null;
        private WingpanelAirPods.DBusObjectManager airpods_beacon_mon = null;
        private WingpanelAirPods.DBusProperties on_batt_mon = null;
        private int64 prev_status_batt_l = 15;
        private int64 prev_status_batt_r = 15;
        private int64 prev_status_batt_case = 15;
        private uint airpods_beacon_discovery_timeout = 0;

        private static GLib.Settings settings;

        public Indicator (Wingpanel.IndicatorManager.ServerType server_type) {
            Object (
                code_name: APPNAME,
                display_name: "Wingpanel AirPods",
                description: "AirPods indicator for Wingpanel"
                );
        }

        construct {

            var provider = new Gtk.CssProvider ();
            provider.load_from_resource ("/com/github/casasfernando/wingpanel-indicator-airpods/icons/Application.css");
            Gtk.StyleContext.add_provider_for_screen (
                Gdk.Screen.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            Gtk.IconTheme.get_default ().add_resource_path ("/com/github/casasfernando/wingpanel-indicator-airpods/icons");

            settings = new GLib.Settings ("com.github.casasfernando.wingpanel-indicator-airpods");

            if (!settings.get_boolean ("airpods-connected") && settings.get_boolean ("display-indicator-connected-only")) {
                settings.set_boolean ("display-indicator-effective", false);
            } else {
                settings.set_boolean ("display-indicator-effective", settings.get_boolean ("display-indicator"));
            }
            visible = settings.get_boolean ("display-indicator-effective");

            settings.bind ("display-indicator-effective", this, "visible", SettingsBindFlags.DEFAULT);

        }

        public override Gtk.Widget get_display_widget () {
            if (display_widget == null) {
                display_widget = new DisplayWidget (settings);
                update_display_widget_data ();
                // Initialize system power source monitor
                on_battery_monitor ();
                // Initialize AirPodsService
                AirPodsService.init ();
                // Check if paired AirPods were detected
                if (settings.get_string ("airpods-mac-addr") != "") {
                    // Initialize AirPods connection monitor
                    airpods_connection_monitor ();
                    // Check if the AirPods are currently connected or not
                    AirPodsService.airpods_connection_check ();
                } else {
                    debug ("wingpanel-indicator-airpods: no paired AirPods detected");
                }
                // Initialize AirPods beacon monitor (also used to detect new paired AirPods after init)
                airpods_beacon_monitor ();
            }
            return display_widget;
        }

        public override Gtk.Widget ? get_widget () {
            if (popover_widget == null) {
                popover_widget = new PopoverWidget (settings);
            }

            return popover_widget;
        }

        public override void opened () {
        }

        public override void closed () {
        }

        private void update_display_widget_data () {
            if (display_widget != null) {
                Timeout.add_seconds (1, () => {
                    display_widget.update_airpods ();
                    update_popover_widget_data ();
                    return true;
                });
            }
        }

        private void update_popover_widget_data () {
            if (popover_widget == null) return;

            int64 airpods_status_batt_l = settings.get_int64 ("airpods-status-batt-l");
            int64 airpods_status_batt_r = settings.get_int64 ("airpods-status-batt-r");
            int64 airpods_status_batt_case = settings.get_int64 ("airpods-status-batt-case");

            popover_widget.update_left_pod (batt_icn (airpods_status_batt_l, settings.get_boolean ("airpods-status-charging-l")), batt_val (airpods_status_batt_l));
            popover_widget.update_right_pod (batt_icn (airpods_status_batt_r, settings.get_boolean ("airpods-status-charging-r")), batt_val (airpods_status_batt_r));
            popover_widget.update_pods_case (batt_icn (airpods_status_batt_case, settings.get_boolean ("airpods-status-charging-case")), batt_val (airpods_status_batt_case));
            popover_widget.update_airpods_disconnected_visibility ();
            popover_widget.update_batt_warn_visibility ();

            settings.changed["airpods-status-batt-l"].connect ( () =>{
                popover_widget.update_left_pod_visibility ();
                int64 status_batt_l = settings.get_int64 ("airpods-status-batt-l");
                if (status_batt_l != prev_status_batt_l && status_batt_l < 3) {
                    airpods_batt_level_notify ("Left AirPod", status_batt_l);
                }
                prev_status_batt_l = status_batt_l;
            });

            settings.changed["airpods-status-batt-r"].connect ( () =>{
                popover_widget.update_right_pod_visibility ();
                int64 status_batt_r = settings.get_int64 ("airpods-status-batt-r");
                if (status_batt_r != prev_status_batt_r && status_batt_r < 3) {
                    airpods_batt_level_notify ("Right AirPod", status_batt_r);
                }
                prev_status_batt_r = status_batt_r;
            });

            settings.changed["airpods-status-batt-case"].connect ( () =>{
                popover_widget.update_pods_case_visibility ();
                int64 status_batt_case = settings.get_int64 ("airpods-status-batt-case");
                if (status_batt_case != prev_status_batt_case && status_batt_case < 3) {
                    airpods_batt_level_notify ("AirPods case", status_batt_case);
                }
                prev_status_batt_case = status_batt_case;
            });
        }

        private void airpods_connection_monitor () {
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to monitor AirPods connection status");

            string airpods_mac_curated = settings.get_string ("airpods-mac-addr").replace (":", "_");
            try {
                airpods_conn_mon = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.DBus.Properties", settings.get_string ("airpods-bt-adapter").concat ("/dev_", airpods_mac_curated));
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to monitor AirPods connection status (%s)", e.message);
            }

            debug ("wingpanel-indicator-airpods: connected to D-Bus. Monitoring connection status of AirPods with MAC %s", airpods_mac_curated);
            airpods_conn_mon.properties_changed.connect((inter, cp) => {
                if (inter == "org.bluez.Device1" && cp.get ("Connected") != null) {
                    debug ("wingpanel-indicator-airpods: AirPods connection status changed (%s)", cp.get ("Connected").get_boolean ().to_string());
                    settings.set_boolean ("airpods-connected", cp.get ("Connected").get_boolean ());
                }
            });

            // Enable/Disable AirPods beacon discovery on AirPods connection/disconnection
            settings.changed["airpods-connected"].connect ( () =>{
                if (settings.get_boolean ("airpods-connected")) {
                    if (settings.get_boolean ("display-indicator")) {
                        settings.set_boolean ("display-indicator-effective", true);
                    }
                    debug ("wingpanel-indicator-airpods: AirPods connected. Starting AirPods beacon discovery.");
                    AirPodsService.airpods_beacon_discovery_start.begin ();
                } else {
                    debug ("wingpanel-indicator-airpods: AirPods disconnected. Stopping automatic AirPods beacon discovery");
                    if (airpods_beacon_discovery_timeout != 0) {
                        GLib.Source.remove (airpods_beacon_discovery_timeout);
                        airpods_beacon_discovery_timeout = 0;
                    }
                    AirPodsService.airpods_beacon_discovery_stop ();
                    AirPodsService.airpods_status_init ();
                    if (settings.get_boolean ("display-indicator-connected-only")) {
                        settings.set_boolean ("display-indicator-effective", false);
                    }
                }
            });

            settings.changed["display-indicator"].connect ( () =>{
                if (!settings.get_boolean ("airpods-connected") && settings.get_boolean ("display-indicator-connected-only")) {
                    settings.set_boolean ("display-indicator-effective", false);
                } else {
                    settings.set_boolean ("display-indicator-effective", settings.get_boolean ("display-indicator"));
                }
            });

            settings.changed["display-indicator-connected-only"].connect ( () =>{
                if (!settings.get_boolean ("airpods-connected") && settings.get_boolean ("display-indicator-connected-only")) {
                    settings.set_boolean ("display-indicator-effective", false);
                } else {
                    settings.set_boolean ("display-indicator-effective", settings.get_boolean ("display-indicator"));
                }
            });

            // Reset beacon discovery mode on system power source change if the AirPods are connected
            settings.changed["system-on-battery"].connect ( () =>{
                if (settings.get_boolean ("airpods-connected")) {
                    reset_beacon_discovery_mode ("system power source change");
                }
            });

            // Reset beacon discovery mode on battery saver mode setting change if the AirPods are connected
            settings.changed["battery-saver-mode"].connect ( () =>{
                if (settings.get_boolean ("airpods-connected")) {
                    reset_beacon_discovery_mode ("battery saver mode setting change");
                }
            });


        }

        private void airpods_beacon_monitor () {
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to monitor AirPods beacons");
            try {
                airpods_beacon_mon = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.DBus.ObjectManager", "/");
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to monitor AirPods beacons (%s)", e.message);
            }
            debug ("wingpanel-indicator-airpods: connected to D-Bus. Monitoring AirPods beacons");

            airpods_beacon_mon.interfaces_added.connect((objpath, iface) => {
                // Check that the signal is for a new org.bluez.Device1 interface
                if (iface.contains ("org.bluez.Device1")) {
                    debug ("wingpanel-indicator-airpods: new bluetooth interface detected");
                    // Check interface address type
                    string addr_type = "";
                    if (iface.get ("org.bluez.Device1").contains ("AddressType")) {
                        addr_type = iface.get ("org.bluez.Device1").get ("AddressType").get_string ();
                        debug ("wingpanel-indicator-airpods: interface address type = '%s'", addr_type);
                        // Check if the interface contains Manufacturer Data
                        bool has_man_data = iface.get ("org.bluez.Device1").contains ("ManufacturerData");
                        // If the address type is public, and we didn't detect any AirPods paired on init, try to detect paired AirPods now
                        if (addr_type == "public" && settings.get_string ("airpods-mac-addr") == "") {
                            debug ("wingpanel-indicator-airpods: trying to determine if the interface belong to paired AirPods");
                            // Detect new paired AirPods
                            AirPodsService.airpods_status_init ();
                            AirPodsService.airpods_detector ();
                            // Check if paired AirPods were detected
                            if (settings.get_string ("airpods-mac-addr") != "") {
                                // Initialize AirPods connection monitor
                                airpods_connection_monitor ();
                                // Check if the AirPods are currently connected or not
                                AirPodsService.airpods_connection_check ();
                            } else {
                                debug ("wingpanel-indicator-airpods: no paired AirPods detected");
                            }
                        // Otherwise if the interface address type is random, contains manufacturer data and AirPods are connected; process it as a BLE beacon
                        } else if (addr_type == "random" && has_man_data && settings.get_boolean ("airpods-connected")) {
                            debug ("wingpanel-indicator-airpods: new BLE beacon detected and contains Manufacturer Data");
                            AirPodsService.airpods_beacon_analyzer (objpath, iface);
                        }
                    } else {
                        debug ("wingpanel-indicator-airpods: the new bluetooth interface doesn't contain an address type. Discarding");
                    }
                } else {
                    debug ("wingpanel-indicator-airpods: not an org.bluez.Device1 interface. Discarding");
                }
            });
        }

        private void on_battery_monitor () {
            // Check current system power source
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to check current system power source");
            try {
                WingpanelAirPods.UPower system_upower = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.UPower", "/org/freedesktop/UPower");
                debug ("wingpanel-indicator-airpods: connected to D-Bus. Checking current system power source");
                bool on_batt = system_upower.on_battery;
                if (on_batt) {
                    debug ("wingpanel-indicator-airpods: system is running on battery");
                    settings.set_boolean ("system-on-battery", true);
                } else {
                    debug ("wingpanel-indicator-airpods: system is not running on battery");
                    settings.set_boolean ("system-on-battery", false);
                }
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to check current system power source (%s)", e.message);
            }

            // Monitor system power source changes
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to monitor system power source changes");
            try {
                on_batt_mon = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.DBus.Properties", "/org/freedesktop/UPower");
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to monitor system power source changes (%s)", e.message);
            }
            debug ("wingpanel-indicator-airpods: connected to D-Bus. Monitoring system power source changes");

            on_batt_mon.properties_changed.connect((inter, cp) => {
                if (inter == "org.freedesktop.UPower" && cp.get ("OnBattery") != null) {
                    debug ("wingpanel-indicator-airpods: system power source changed. Running on battery (%s)", cp.get ("OnBattery").get_boolean ().to_string());
                    settings.set_boolean ("system-on-battery", cp.get ("OnBattery").get_boolean ());
                }
            });

        }

        private void reset_beacon_discovery_mode (string reason) {
            if (settings.get_boolean ("battery-saver-mode") && settings.get_boolean ("system-on-battery")) {
                debug ("wingpanel-indicator-airpods: stopping automatic AirPods beacon discovery due to ".concat (reason));
                AirPodsService.airpods_beacon_discovery_stop ();
                // Set the timer to automatically discover AirPods beacon every 60 seconds
                debug ("wingpanel-indicator-airpods: starting automatic AirPods beacon discovery every 60 seconds (battery saver mode: on)");
                airpods_beacon_discovery_timeout = Timeout.add_seconds (60, () => {
                    AirPodsService.airpods_beacon_discovery_start.begin ();
                    return true;
                });
                AirPodsService.airpods_beacon_discovery_start.begin ();
                airpods_notify ("Battery saver mode engaged", "In order to preserve system battery life some indicator features will be disabled and AirPods battery level report may be less accurate.");
            } else {
                debug ("wingpanel-indicator-airpods: stopping automatic AirPods beacon discovery due to ".concat (reason));
                AirPodsService.airpods_beacon_discovery_stop ();
                if (airpods_beacon_discovery_timeout != 0) {
                    GLib.Source.remove (airpods_beacon_discovery_timeout);
                    airpods_beacon_discovery_timeout = 0;
                }
                debug ("wingpanel-indicator-airpods: starting automatic AirPods beacon discovery (battery saver mode: off)");
                AirPodsService.airpods_beacon_discovery_start.begin ();
                airpods_notify ("Battery saver mode disengaged", "Re-enabling all indicator features");
            }
        }

        private string batt_icn (int64 batt_lvl, bool batt_chrg) {
            string batt_icon = "";
            if (batt_lvl < 1) {
                batt_icon = "battery-empty";
            } else if (batt_lvl < 3) {
                batt_icon = "battery-caution";
            } else if (batt_lvl < 6) {
                batt_icon = "battery-low";
            } else if (batt_lvl < 8) {
                batt_icon = "battery-good";
            } else if (batt_lvl == 15) {
                batt_icon = "battery-missing";
            } else {
                batt_icon = "battery-full";
            }

            if (batt_chrg && batt_lvl != 15) { batt_icon = batt_icon.concat ("-charging"); }

            return batt_icon;
        }

        private string batt_val (int64 batt_lvl) {
            string batt_value = "";
            if (batt_lvl != 15) {
                batt_value = (batt_lvl * 10).to_string ().concat ("% remaining");
            } else {
                batt_value = "Not Connected";
            }
            return batt_value;
        }

        private void airpods_batt_level_notify (string element, int64 blvl) {
            string nbody = "";
            if (blvl < 1) {
                nbody = element.concat (" battery level is critical and it needs to be recharged immediately");
            } else {
                nbody = element.concat (" battery level is low and it will need to be recharged soon.");
            }
            airpods_notify ("Battery level alert", nbody);
            return;
        }

        private void airpods_notify (string title, string body) {
            Notify.init ("com.github.casasfernando.wingpanel-indicator-airpods");
            var notification = new Notify.Notification (title, body, "com.github.casasfernando.wingpanel-indicator-airpods");
            notification.set_app_name ("Wingpanel AirPods");
            notification.set_hint ("desktop-entry", "com.github.casasfernando.wingpanel-indicator-airpods");
            notification.set_urgency (Notify.Urgency.LOW);
            try {
                notification.show ();
            } catch (Error e) {
                warning ("wingpanel-indicator-airpods: %s", e.message);
            }
            return;
        }

    }
}

public Wingpanel.Indicator ? get_indicator (Module module, Wingpanel.IndicatorManager.ServerType server_type) {
    debug ("wingpanel-indicator-airpods: loading airpods indicator");

    if (server_type != Wingpanel.IndicatorManager.ServerType.SESSION) {
        debug ("wingpanel-indicator-airpods: Wingpanel is not in session, not loading wingpanel-indicator-airpods indicator");
        return null;
    }

    var indicator = new WingpanelAirPods.Indicator (server_type);

    return indicator;
}
