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
        private WingpanelAirPods.DBusProperties batt_charge_mon = null;
        private WingpanelAirPods.DBusProperties on_batt_mon = null;
        private int64 prev_status_batt_l = 15;
        private int64 prev_status_batt_r = 15;
        private int64 prev_status_batt_case = 15;
        private uint airpods_beacon_discovery_timeout = 0;
        private Gee.HashSet<string> mpris_wait_for_stop = new Gee.HashSet<string> ();

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
                    return GLib.Source.CONTINUE;
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
                    airpods_batt_level_notify (_("Left AirPod"), status_batt_l);
                }
                prev_status_batt_l = status_batt_l;
            });

            settings.changed["airpods-status-batt-r"].connect ( () =>{
                popover_widget.update_right_pod_visibility ();
                int64 status_batt_r = settings.get_int64 ("airpods-status-batt-r");
                if (status_batt_r != prev_status_batt_r && status_batt_r < 3) {
                    airpods_batt_level_notify (_("Right AirPod"), status_batt_r);
                }
                prev_status_batt_r = status_batt_r;
            });

            settings.changed["airpods-status-batt-case"].connect ( () =>{
                popover_widget.update_pods_case_visibility ();
                int64 status_batt_case = settings.get_int64 ("airpods-status-batt-case");
                if (status_batt_case != prev_status_batt_case && status_batt_case < 3) {
                    airpods_batt_level_notify (_("AirPods case"), status_batt_case);
                }
                prev_status_batt_case = status_batt_case;
            });
        }

        private void airpods_connection_monitor () {
            string airpods_mac_curated = settings.get_string ("airpods-mac-addr").replace (":", "_");
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to monitor AirPods with MAC %s connection status", airpods_mac_curated);
            try {
                airpods_conn_mon = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.DBus.Properties", settings.get_string ("airpods-bt-adapter").concat ("/dev_", airpods_mac_curated));
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to monitor AirPods connection status (%s)", e.message);
            }

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
                    reset_beacon_discovery_mode ("AirPods connected");
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
                    engage_battery_saver_mode ("system power source change");
                }
            });

            // Reset beacon discovery mode on battery saver mode setting change if the AirPods are connected and we are running on battery
            settings.changed["battery-saver-mode"].connect ( () =>{
                if (settings.get_boolean ("airpods-connected") && settings.get_boolean ("system-on-battery")) {
                    engage_battery_saver_mode ("battery saver mode setting change");
                }
            });

            // Reset beacon discovery mode on battery saver mode threshold setting change if the AirPods are connected and we are running on battery
            settings.changed["battery-saver-mode-threshold"].connect ( () =>{
                if (settings.get_boolean ("airpods-connected") && settings.get_boolean ("system-on-battery")) {
                    engage_battery_saver_mode ("battery saver mode threshold setting change");
                }
            });

            // Reset beacon discovery mode on system battery charge change if the AirPods are connected and we are running on battery
            settings.changed["system-battery-percentage"].connect ( () =>{
                if (settings.get_boolean ("airpods-connected") && settings.get_boolean ("system-on-battery")) {
                    engage_battery_saver_mode ("system battery charge change");
                }
            });

            // On in-ear status change control media player playback
            settings.changed["airpods-status-inear-l"].connect ( () =>{
                // Ignore signal:
                // - while any AirPod is in the charging case and the case lid is open
                // - when battery saver mode is engaged
                // - when the AirPods are not connected
                if (!settings.get_boolean ("airpods-status-charging-l") && !settings.get_boolean ("airpods-status-charging-r") && !settings.get_boolean ("battery-saver-mode-engaged") && settings.get_boolean ("airpods-connected")) {
                    debug ("wingpanel-indicator-airpods: in-ear status change (left AirPod)");
                    if (settings.get_boolean ("airpods-status-inear-l") && settings.get_boolean ("airpods-status-inear-r")) {
                        // a- Resume playback if paused
                        airpods_mplayer_control (1);
                    } else if (!settings.get_boolean ("airpods-status-inear-l") && settings.get_boolean ("airpods-status-inear-r")) {
                        // b- Pause playback if playing
                        airpods_mplayer_control (2);
                    } else if (settings.get_boolean ("airpods-status-inear-l") && !settings.get_boolean ("airpods-status-inear-r")) {
                        // c- Play or Resume playback if paused
                        airpods_mplayer_control (1);
                    } else if (!settings.get_boolean ("airpods-status-inear-l") && !settings.get_boolean ("airpods-status-inear-r")) {
                        // d- Pause playback if playing. Wait 15 seconds, then Stop playback if it wasn't resumed in the meantime
                        airpods_mplayer_control (3);
                    }
                }
            });

            // On in-ear status change control media player playback
            settings.changed["airpods-status-inear-r"].connect ( () =>{
                // Ignore signal:
                // - while any AirPod is in the charging case and the case lid is open
                // - when battery saver mode is engaged
                // - when the AirPods are not connected
                if (!settings.get_boolean ("airpods-status-charging-l") && !settings.get_boolean ("airpods-status-charging-r") && !settings.get_boolean ("battery-saver-mode-engaged") && settings.get_boolean ("airpods-connected")) {
                    debug ("wingpanel-indicator-airpods: in-ear status change (right AirPod)");
                    if (settings.get_boolean ("airpods-status-inear-l") && settings.get_boolean ("airpods-status-inear-r")) {
                        // a- Resume playback if paused
                        airpods_mplayer_control (1);
                    } else if (settings.get_boolean ("airpods-status-inear-l") && !settings.get_boolean ("airpods-status-inear-r")) {
                        // b- Pause playback if playing
                        airpods_mplayer_control (2);
                    } else if (!settings.get_boolean ("airpods-status-inear-l") && settings.get_boolean ("airpods-status-inear-r")) {
                        // c- Play or Resume playback if paused
                        airpods_mplayer_control (1);
                    } else if (!settings.get_boolean ("airpods-status-inear-l") && !settings.get_boolean ("airpods-status-inear-r")) {
                        // d- Pause playback if playing. Wait 15 seconds, then Stop playback if it wasn't resumed in the meantime
                        airpods_mplayer_control (3);
                    }
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

            airpods_beacon_mon.interfaces_added.connect((objpath, iface) => {
                // Check that the signal is for a new org.bluez.Device1 interface
                if (iface.contains ("org.bluez.Device1")) {
                    debug ("wingpanel-indicator-airpods: new bluetooth interface detected");
                    // Check interface address type
                    string addr_type = "";
                    if (iface.get ("org.bluez.Device1").contains ("AddressType")) {
                        addr_type = iface.get ("org.bluez.Device1").get ("AddressType").get_string ();
                        debug ("wingpanel-indicator-airpods: interface address type: %s", addr_type);
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
            // Detect if the system has a battery device
            bool has_battery = false;
            ObjectPath batt_dev= new ObjectPath ("/");
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to detect system battery device");
            try {
                WingpanelAirPods.UPower system_upower_get_devices = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.UPower", "/org/freedesktop/UPower");
                ObjectPath[] system_upower_devices = system_upower_get_devices.enumerate_devices ();
                foreach (ObjectPath system_upower_device in system_upower_devices) {
                    WingpanelAirPods.UPowerDevice system_upower_device_properties = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.UPower", system_upower_device);
                    // Check if the device is a system battery
                    if (system_upower_device_properties.device_type == 2) {
                        has_battery = true;
                        batt_dev = system_upower_device;
                        debug ("wingpanel-indicator-airpods: system battery detected. Device path: %s", system_upower_device);
                        // Check current system battery charge
                        settings.set_double ("system-battery-percentage", system_upower_device_properties.percentage);
                        debug ("wingpanel-indicator-airpods: current system battery charge %s%%", system_upower_device_properties.percentage.to_string ());
                        // Alternative method to calculate system battery charge
                        //double my_batt_percentage = (system_upower_device_properties.energy - system_upower_device_properties.energy_empty) / (system_upower_device_properties.energy_full - system_upower_device_properties.energy_empty) * 100;
                        //debug ("wingpanel-indicator-airpods: current system battery charge %s%%", my_batt_percentage.to_string ());
                        break;
                    }
                }
                if (!has_battery) {
                    debug ("wingpanel-indicator-airpods: no system battery detected");
                }
            } catch (Error e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to detect system battery device path (%s)", e.message);
            }

            // If the system has a battery
            if (has_battery) {
                // Check current system power source
                debug ("wingpanel-indicator-airpods: connecting to D-Bus to check current system power source");
                try {
                    WingpanelAirPods.UPower system_upower_get_on_batt = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.UPower", "/org/freedesktop/UPower");
                    bool on_batt = system_upower_get_on_batt.on_battery;
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

                on_batt_mon.properties_changed.connect((inter, cp) => {
                    if (inter == "org.freedesktop.UPower" && cp.get ("OnBattery") != null) {
                        debug ("wingpanel-indicator-airpods: system power source changed. Running on battery (%s)", cp.get ("OnBattery").get_boolean ().to_string ());
                        settings.set_boolean ("system-on-battery", cp.get ("OnBattery").get_boolean ());
                    }
                });

                // Monitor system battery charge changes
                debug ("wingpanel-indicator-airpods: connecting to D-Bus to monitor system battery charge changes");
                try {
                    batt_charge_mon = Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.DBus.Properties", batt_dev);
                } catch (IOError e) {
                    warning ("wingpanel-indicator-airpods: can't connect to D-Bus to monitor system battery charge changes (%s)", e.message);
                }

                batt_charge_mon.properties_changed.connect((inter, cp) => {
                    if (inter == "org.freedesktop.UPower.Device" && cp.get ("Percentage") != null) {
                        debug ("wingpanel-indicator-airpods: system battery charge changed. System battery %s%% charged", cp.get ("Percentage").get_double ().to_string ());
                        settings.set_double ("system-battery-percentage", cp.get ("Percentage").get_double ());
                    }
                });
            } else {
                settings.set_boolean ("system-on-battery", false);
            }

            engage_battery_saver_mode ("indicator startup");

        }

        private void engage_battery_saver_mode (string reason) {
            // Engage/Disengage battery saver mode
            if ((settings.get_int ("battery-saver-mode") == 2 || (settings.get_int ("battery-saver-mode") == 1 && settings.get_double ("system-battery-percentage") <= settings.get_int ("battery-saver-mode-threshold"))) && settings.get_boolean ("system-on-battery")) {
                if (!settings.get_boolean ("battery-saver-mode-engaged")) {
                    settings.set_boolean ("battery-saver-mode-engaged", true);
                    // Reset beacon discovery mode if the AirPods are connected
                    if (settings.get_boolean ("airpods-connected") && reason != "indicator startup") {
                        reset_beacon_discovery_mode (reason);
                    }
                }
            } else {
                if (settings.get_boolean ("battery-saver-mode-engaged")) {
                    settings.set_boolean ("battery-saver-mode-engaged", false);
                    // Reset beacon discovery mode if the AirPods are connected
                    if (settings.get_boolean ("airpods-connected") && reason != "indicator startup") {
                        reset_beacon_discovery_mode (reason);
                    }
                }
            }
        }

        private void reset_beacon_discovery_mode (string reason) {
            // Check if the bluetooth adapter is discovering beacons and stop it if needed
            if (AirPodsService.airpods_beacon_discovery_status ()) {
                debug ("wingpanel-indicator-airpods: stopping automatic AirPods beacon discovery due to ".concat (reason));
                AirPodsService.airpods_beacon_discovery_stop ();
            }
            // Restart beacon discovery
            if (settings.get_boolean ("battery-saver-mode-engaged")) {
                // Set the timer to automatically discover AirPods beacon every 60 seconds
                debug ("wingpanel-indicator-airpods: starting automatic AirPods beacon discovery every 60 seconds (battery saver mode: on)");
                airpods_beacon_discovery_timeout = Timeout.add_seconds (60, () => {
                    AirPodsService.airpods_beacon_discovery_start.begin ();
                    return GLib.Source.CONTINUE;
                });
                AirPodsService.airpods_beacon_discovery_start.begin ();
                airpods_notify (_("Battery saver mode engaged"), _("In order to preserve system battery life some indicator features (e.g. media player playback control using AirPods in-ear detection) will be disabled and AirPods battery level report may be less accurate."));
            } else {
                // Remove the time to automatically discover AirPods beacon every 60 seconds if present
                if (airpods_beacon_discovery_timeout != 0) {
                    GLib.Source.remove (airpods_beacon_discovery_timeout);
                    airpods_beacon_discovery_timeout = 0;
                }
                debug ("wingpanel-indicator-airpods: starting automatic AirPods beacon discovery (battery saver mode: off)");
                AirPodsService.airpods_beacon_discovery_start.begin ();
                if (reason != "AirPods connected") {
                    airpods_notify (_("Battery saver mode disengaged"), _("Re-enabling all indicator features"));
                }
            }
        }

        private void airpods_mplayer_control (uint8 action) {
            // Connect to DBus to get the list names available in the session
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to get the list of MPRIS media players available in the session");
            try {
                WingpanelAirPods.DBus dbus_names_conn = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.DBus", "/org/freedesktop/DBus");
                string[] dbus_names = dbus_names_conn.list_names ();
                // Go through the list of names looking for the ones that contain 'org.mpris.MediaPlayer2'
                foreach (string dbus_name in dbus_names) {
                    if (dbus_name.contains ("org.mpris.MediaPlayer2")) {
                        // Check media player playback status
                        debug ("wingpanel-indicator-airpods: connecting to D-Bus to control MPRIS media player playback (%s)", dbus_name);
                        try {
                            WingpanelAirPods.MediaPlayer mplayer = Bus.get_proxy_sync (BusType.SESSION, dbus_name, "/org/mpris/MediaPlayer2");
                            // Resume playback if paused
                            if (action == 1 && mplayer.playback_status == "Paused") {
                                debug ("wingpanel-indicator-airpods: play/resume MPRIS media player playback (%s)", dbus_name);
                                // Remove the MPRIS media player from the pending Stop playback list
                                if (mpris_wait_for_stop.contains (dbus_name)) {
                                    mpris_wait_for_stop.remove (dbus_name);
                                }
                                mplayer.play ();
                            // Pause playback if playing
                            } else if (action == 2 && mplayer.playback_status == "Playing") {
                                debug ("wingpanel-indicator-airpods: pause MPRIS media player playback (%s)", dbus_name);
                                mplayer.pause ();
                            // Pause, wait 15 seconds, then Stop playback if not resumed
                            } else if (action == 3 && (mplayer.playback_status == "Playing" || mplayer.playback_status == "Paused")) {
                                debug ("wingpanel-indicator-airpods: pause, wait, stop MPRIS media player playback (%s)", dbus_name);
                                // Pause playback if playing
                                if (mplayer.playback_status == "Playing") {
                                    mplayer.pause ();
                                }
                                // Add MPRIS media player to the pending Stop playback list
                                mpris_wait_for_stop.add (dbus_name);
                                // Wait and Stop media player playback if not resumed
                                airpods_mplayer_control_stop.begin (dbus_name);
                            }
                        } catch (Error e) {
                            warning ("wingpanel-indicator-airpods: can't connect to D-Bus to control MPRIS media player playback (%s). Error: %s", dbus_name, e.message);
                        }
                    }
                }
            } catch (Error e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to get the list of MPRIS media players available in the session (%s)", e.message);
            }
        }

        private async void airpods_mplayer_control_stop (string mplayer_dbus_name) {
            // Wait for 15 seconds
            yield AirPodsService.airpods_wait_timeout (15);
            // Stop playback
            if (mpris_wait_for_stop.contains (mplayer_dbus_name)) {
                debug ("wingpanel-indicator-airpods: connecting to D-Bus to stop MPRIS media player playback (%s)", mplayer_dbus_name);
                try {
                    WingpanelAirPods.MediaPlayer mplayer = Bus.get_proxy_sync (BusType.SESSION, mplayer_dbus_name, "/org/mpris/MediaPlayer2");
                    if (mplayer.playback_status == "Paused") {
                        mplayer.stop ();
                    }
                    mpris_wait_for_stop.remove (mplayer_dbus_name);
                } catch (Error e) {
                    warning ("wingpanel-indicator-airpods: can't connect to D-Bus to stop MPRIS media player playback (%s). Error: %s", mplayer_dbus_name, e.message);
                }
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
                batt_value = (batt_lvl * 10).to_string ().concat (_("% charged"));
            } else {
                batt_value = _("Not Connected");
            }
            return batt_value;
        }

        private void airpods_batt_level_notify (string element, int64 blvl) {
            string nbody = "";
            if (blvl < 1) {
                nbody = element.concat (_(" battery level is critical and it needs to be recharged immediately"));
            } else {
                nbody = element.concat (_(" battery level is low and it will need to be recharged soon."));
            }
            airpods_notify (_("Battery level alert"), nbody);
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
