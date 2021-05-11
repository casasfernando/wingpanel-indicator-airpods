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
    public class AirPodsService : GLib.Object {

        private static int64 leftStatus = 15;
        private static int64 rightStatus = 15;
        private static int64 caseStatus = 15;
        private static bool chargeL = false;
        private static bool chargeR = false;
        private static bool chargeCase = false;
        private static bool inEarL = false;
        private static bool inEarR = false;
        private const string MODEL_AIRPODS_NORMAL = "airpods12";
        private const string MODEL_AIRPODS_PRO = "airpodspro";
        private static string model = MODEL_AIRPODS_NORMAL;
        private static int16 strongest_rssi = -75;

        private static GLib.Settings settings;

        public AirPodsService () {
        }

        public static void init () {
            settings = new GLib.Settings ("com.github.casasfernando.wingpanel-indicator-airpods");
            airpods_status_init ();
            airpods_detector ();
        }

        public static void airpods_status_init () {
            settings.set_boolean ("airpods-connected", false);
            settings.set_int64 ("airpods-status-batt-l", 15);
            settings.set_int64 ("airpods-status-batt-r", 15);
            settings.set_int64 ("airpods-status-batt-case", 15);
            settings.set_boolean ("airpods-status-charging-l", false);
            settings.set_boolean ("airpods-status-charging-r", false);
            settings.set_boolean ("airpods-status-charging-case", false);
            settings.set_boolean ("airpods-status-inear-l", false);
            settings.set_boolean ("airpods-status-inear-r", false);
            settings.set_string ("airpods-status-model", "airpods12");
        }

        public static void airpods_detector () {
            // Detect paired AirPods
            WingpanelAirPods.DBusObjectManager airpods_detect = null;

            debug ("wingpanel-indicator-airpods: connecting to D-Bus to detect paired AirPods");

            try {
                airpods_detect = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", "/");
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to detect paired AirPods (%s)", e.message);
            }

            debug ("wingpanel-indicator-airpods: connected to D-Bus. Detecting paired AirPods");

            try {
                airpods_detect.get_managed_objects ().foreach ((k1, v1) => {
                    v1.foreach ((k2, v2) => {
                        if (k2 == "org.bluez.Device1" && v2.get ("Paired").get_boolean ()) {
                            string[] uuids = (string[]) v2.get ("UUIDs");
                            for (uint u = 0; u < uuids.length; u++) {
                                if (uuids[u] == "74ec2172-0bad-4d01-8f77-997b2be0722a" || uuids[u] == "2a72e02b-7b99-778f-014d-ad0b7221ec74") {
                                    settings.set_string ("airpods-bt-adapter", v2.get ("Adapter").get_string());
                                    settings.set_string ("airpods-mac-addr", v2.get ("Address").get_string());
                                    settings.set_string ("airpods-name", v2.get ("Name").get_string());
                                    debug ("wingpanel-indicator-airpods: paired AirPods detected. Name '%s'. MAC address '%s'. Adapter '%s'", v2.get ("Name").get_string(), v2.get ("Address").get_string(), v2.get ("Adapter").get_string());
                                }
                            }
                        }
                    });
                });
            } catch (DBusError dbe) {
                warning ("wingpanel-indicator-airpods: can't retrieve paired devices (%s)", dbe.message);
            } catch (IOError ioe) {
                warning ("wingpanel-indicator-airpods: can't retrieve paired devices (%s)", ioe.message);
            }
        }

        public static void airpods_connection_check () {
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to check current AirPods connection status");

            string airpods_mac_curated = settings.get_string ("airpods-mac-addr").replace (":", "_");
            try {
                WingpanelAirPods.Device airpods_dev = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", settings.get_string ("airpods-bt-adapter").concat ("/dev_", airpods_mac_curated));
                debug ("wingpanel-indicator-airpods: connected to D-Bus. Checking AirPods connection status");
                bool airpods_connected_val = airpods_dev.connected;
                if (airpods_connected_val) {
                    debug ("wingpanel-indicator-airpods: AirPods are currently connected");
                    settings.set_boolean ("airpods-connected", true);
                } else {
                    debug ("wingpanel-indicator-airpods: AirPods are currently disconnected");
                    settings.set_boolean ("airpods-connected", false);
                }
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to check current AirPods connection status (%s)", e.message);
            }

        }

        /*
         * The method below, 'airpods_beacon_analyzer', is in charge of decoding the AirPods BLE beacon to get the current status.
         * The code is based on the algorithm developed by Federico Dossena (https://github.com/adolfintel) for the 
         * OpenPods (https://github.com/adolfintel/OpenPods) project.
         * The original code can be found here: https://github.com/adolfintel/OpenPods/blob/master/OpenPods/app/src/main/java/com/dosse/airpods/PodsService.java
         *
         * - When a beacon arrives that looks like a pair of AirPods, look at the other beacons received in the last 10 seconds and get the strongest one
         * - If the strongest beacon's fake address is the same as this, use this beacon; otherwise use the strongest beacon
         * - Filter for signals stronger than -75dBm in our case
         * - Decode
         * Decoding the beacon:
         * This was done through reverse engineering. Hopefully it's correct.
         * - The beacon coming from a pair of AirPods contains a manufacturer specific data field n°76 of 27 bytes
         * - We convert this data to a hexadecimal string
         * - The 12th and 13th characters in the string represent the charge of the left and right pods.
         *   Under unknown circumstances[1], they are right and left instead (see isFlipped).
         *   Values between 0 and 10 are battery 0-100%; Value 15 means it's disconnected
         * - The 15th character in the string represents the charge of the case. Values between 0 and 10 are battery 0-100%; Value 15 means it's disconnected
         * - The 14th character in the string represents the "in charge" status. Bit 0 (LSB) is the left pod; Bit 1 is the right pod; Bit 2 is the case.
         *   Bit 3 might be case open/closed but I'm not sure and it's not used
         * - The 11th character in the string represents the in-ear detection status. Bit 1 is the left pod; Bit 3 is the right pod.
         * - The 7th character in the string represents the AirPods model (E=AirPods pro)
         *
         * After decoding a beacon, the status is written to leftStatus, rightStatus, caseStatus, chargeL, chargeR, chargeCase, inEarL, inEarR 
         * so that the NotificationThread can use the information
         *
         * Notes:
         * [1] - isFlipped set by bit 1 of 10th character in the string; seems to be related to in-ear detection;
         *
         */
        public static void airpods_beacon_analyzer (ObjectPath objpath, HashTable<string, HashTable<string, Variant>> iface) {
            debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] analyzing new BLE beacon");
            Variant iface_mandata = iface.get ("org.bluez.Device1").get ("ManufacturerData");
            uint16 iface_mandata_company;
            Variant iface_mandata_data;
            VariantIter iter = iface_mandata.iterator ();
            iter.next ("{qv}", out iface_mandata_company, out iface_mandata_data);
            // Check if the Manufacturer Data company value is Apple and the advertisement data size is 27 bytes
            if (iface_mandata_company == 76 && iface_mandata_data.n_children() == 27) {
                debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] ManufacturerData company = Apple (%s). ManufacturerData data size = %s bytes. AirPods beacon found!", iface_mandata_company.to_string(), iface_mandata_data.n_children().to_string());
                // Get RSSI value
                if (iface.get ("org.bluez.Device1").contains ("RSSI")) {
                    int16 rssi = iface.get ("org.bluez.Device1").get ("RSSI").get_int16 ();
                    debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] beacon signal strength (RSSI) = %sdBm", rssi.to_string ());
                    // Check if RSSI value is stronger than -75dBm (the device is not too far away)
                    // and stronger than previous decoded beacons otherwise discard it
                    if (rssi > strongest_rssi) {
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] strong AirPods beacon received. Decoding it.");
                        // Update strongest beacon RSSI detected
                        strongest_rssi = rssi;
                        // Prepare beacon data to be decoded
                        uint8[] iface_mandata_dataArr = (uint8[]) iface_mandata_data;
                        // Decode beacon data
                        string decoded_beacon = decodeHex (iface_mandata_dataArr);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] decoded AirPods beacon = %s", decoded_beacon);
                        bool flip = isFlipped (decoded_beacon);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] isFlipped = %s", flip.to_string());
                        // Left AirPod (0-10 batt; 15=disconnected)
                        leftStatus = decoded_beacon.substring(flip ? 12 : 13, 1).to_int64 (null, 16);
                        settings.set_int64 ("airpods-status-batt-l", leftStatus);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] leftStatus = %s", leftStatus.to_string());
                        // Right AirPod (0-10 batt; 15=disconnected)
                        rightStatus = decoded_beacon.substring(flip ? 13 : 12, 1).to_int64 (null, 16);
                        settings.set_int64 ("airpods-status-batt-r", rightStatus);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] rightStatus = %s", rightStatus.to_string());
                        // Case (0-10 batt; 15=disconnected)
                        caseStatus = decoded_beacon.substring(15, 1).to_int64 (null, 16);
                        settings.set_int64 ("airpods-status-batt-case", caseStatus);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] caseStatus = %s", caseStatus.to_string());
                        // Charge status (bit 0=left; bit 1=right; bit 2=case)
                        int64 chargeStatus = decoded_beacon.substring(14, 1).to_int64 (null, 16);
                        chargeL = (chargeStatus & (flip ? 0x2 : 0x1)) != 0;
                        settings.set_boolean ("airpods-status-charging-l", chargeL);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] chargeL = %s", chargeL.to_string());
                        chargeR = (chargeStatus & (flip ? 0x1 : 0x2)) != 0;
                        settings.set_boolean ("airpods-status-charging-r", chargeR);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] chargeR = %s", chargeR.to_string());
                        chargeCase = (chargeStatus & 0x4) != 0;
                        settings.set_boolean ("airpods-status-charging-case", chargeCase);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] chargeCase = %s", chargeCase.to_string());
                        // InEar status (bit 1=left; bit 3=right)
                        int64 inEarStatus = decoded_beacon.substring(11, 1).to_int64 (null, 16);
                        inEarL = (inEarStatus & (flip ? 0x8 : 0x2)) != 0;
                        settings.set_boolean ("airpods-status-inear-l", inEarL);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] inEarL = %s", inEarL.to_string());
                        inEarR = (inEarStatus & (flip ? 0x2 : 0x8)) != 0;
                        settings.set_boolean ("airpods-status-inear-r", inEarR);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] inEarR = %s", inEarR.to_string());
                        // Detect if these are AirPods Pro or regular ones
                        model = (decoded_beacon.substring(7, 1) == "E") ? MODEL_AIRPODS_PRO : MODEL_AIRPODS_NORMAL;
                        settings.set_string ("airpods-status-model", model);
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] model = %s", model);
                    } else {
                        debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] BLE beacon signal strength is weaker than -60dBm or weaker than previously decoded AirPods beacons. Discarding");
                    }
                } else {
                    debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] BLE beacon doesn't contain RSSI value. Discarding");
                }
            } else {
                debug ("wingpanel-indicator-airpods: [airpods-beacon-analyzer] BLE beacon Manufacturer Data company != Apple or Manufacturer Data data size != 27 bytes. Discarding");
            }
            // Remove interface
            AirPodsService.airpods_interface_remove (objpath);

        }

        public static async void airpods_beacon_discovery_start () {
            WingpanelAirPods.Adapter airpods_adpt = null;
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to start AirPods beacon discovery");
            try {
                airpods_adpt = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", settings.get_string ("airpods-bt-adapter"));
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus (%s)", e.message);
            }

            debug ("wingpanel-indicator-airpods: Setting AirPods beacon discovery filter");
            HashTable<string, Variant> filter = new HashTable<string, Variant> (str_hash, str_equal);
            filter.insert("Transport", new Variant.string ("le"));
            //filter.insert("DuplicateData", new Variant.boolean (false));
            try {
                airpods_adpt.set_discovery_filter (filter);
            } catch (Error e) {
                warning ("wingpanel-indicator-airpods: can't set AirPods beacon discovery filter (%s)", e.message);
            }

            debug ("wingpanel-indicator-airpods: Starting AirPods beacon discovery");
            airpods_adpt.start_discovery.begin ();
            yield airpods_beacon_discovery_timeout (15);
            airpods_beacon_discovery_stop ();
            strongest_rssi = -60;
        }

        public static void airpods_beacon_discovery_stop () {
            WingpanelAirPods.Adapter airpods_adpt = null;
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to stop AirPods beacon discovery");
            try {
                airpods_adpt = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", settings.get_string ("airpods-bt-adapter"));
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus (%s)", e.message);
            }
            debug ("wingpanel-indicator-airpods: Stopping AirPods beacon discovery");
            airpods_adpt.stop_discovery.begin ();
        }

        public static void airpods_interface_remove (ObjectPath iface) {
            WingpanelAirPods.Adapter airpods_adpt = null;
            debug ("wingpanel-indicator-airpods: connecting to D-Bus to remove BLE beacon interface");
            try {
                airpods_adpt = Bus.get_proxy_sync (BusType.SYSTEM, "org.bluez", settings.get_string ("airpods-bt-adapter"));
            } catch (IOError e) {
                warning ("wingpanel-indicator-airpods: can't connect to D-Bus to remove BLE beacon interface (%s)", e.message);
            }

            debug ("wingpanel-indicator-airpods: removing beacon interface");
            try {
                airpods_adpt.remove_device (iface);
            } catch (Error e) {
                warning ("wingpanel-indicator-airpods: can't remove BLE beacon interface (%s)", e.message);
            }
        }

        private static string decodeHex (uint8[] bArr) {
            StringBuilder retval = new StringBuilder();
            for (uint b = 0; b < bArr.length; b++) {
                retval.append_printf ("%02X", bArr[b]);
            }
            return retval.str;
        }

        private static bool isFlipped (string str) {

            return (str.substring (10, 1).to_int64 (null, 16) & 0x02) == 0;

        }

        private static async void airpods_beacon_discovery_timeout (uint seconds) {
            Timeout.add_seconds (seconds, () => {
                airpods_beacon_discovery_timeout.callback ();
                return false;
            });
            yield;
        }

    }
}
