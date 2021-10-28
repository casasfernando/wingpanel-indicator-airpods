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
    public class DisplayWidget : Gtk.Grid {
        private IndicatorWidget airpods_info;

        public unowned Settings settings { get; construct set; }

        public DisplayWidget (Settings settings) {
            Object (settings: settings);
        }

        construct {

            valign = Gtk.Align.CENTER;

            airpods_info = new IndicatorWidget ("airpods-disconnected-symbolic", 4);

            add (airpods_info);

        }

        public void update_airpods () {

            // Update indicator icon
            if (settings.get_boolean ("airpods-connected")) {
                airpods_info.new_icon = "airpods-connected-symbolic";
            } else {
                airpods_info.new_icon = "airpods-disconnected-symbolic";
            }

            // Update indicator label
            int64 airpod_batt_l = settings.get_int64 ("airpods-status-batt-l");
            int64 airpod_batt_r = settings.get_int64 ("airpods-status-batt-r");
            if (airpod_batt_l != 15 && airpod_batt_r != 15) {
                airpods_info.label_value = ((((float) airpod_batt_l + (float) airpod_batt_r) / 2) * 10).to_string ().concat ("%");
            } else if (airpod_batt_l != 15) {
                airpods_info.label_value = (airpod_batt_l * 10).to_string ().concat ("%");
            } else if (airpod_batt_r != 15) {
                airpods_info.label_value = (airpod_batt_r * 10).to_string ().concat ("%");
            } else {
                airpods_info.label_value = _("N/A");
            }

            // Show battery percentage in the indicator only if the AirPods are connected
            bool show_batt = false;
            if (settings.get_boolean ("airpods-connected") && settings.get_boolean ("display-indicator-battery")) {
                show_batt = true;
            }
            airpods_info.show_batt = show_batt;

        }

    }
}
