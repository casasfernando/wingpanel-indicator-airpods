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
    public class TogglesWidget : Gtk.Grid {
        private Granite.SwitchModelButton indicator;
        private Granite.SwitchModelButton indicator_connected_only;
        private Granite.SwitchModelButton indicator_notifications;
        private ComboRow battery_saver_mode;
        private SpinRow battery_saver_mode_threshold_spin;

        public unowned Settings settings { get; construct set; }

        public TogglesWidget (Settings settings) {
            Object (settings: settings, hexpand: true);
        }

        construct {
            orientation = Gtk.Orientation.VERTICAL;
            row_spacing = 6;

            // Enable indicator switch
            indicator = new Granite.SwitchModelButton ("Show indicator");
            indicator.set_active (settings.get_boolean ("display-indicator"));
            settings.bind ("display-indicator", indicator, "active", SettingsBindFlags.DEFAULT);

            // Enable indicator only when the AirPods are connected switch
            indicator_connected_only = new Granite.SwitchModelButton ("Show indicator only when AirPods are connected");
            indicator_connected_only.set_active (settings.get_boolean ("display-indicator-connected-only"));
            settings.bind ("display-indicator-connected-only", indicator_connected_only, "active", SettingsBindFlags.DEFAULT);

            // Enable notifications
            indicator_notifications = new Granite.SwitchModelButton ("Show notifications");
            indicator_notifications.set_active (settings.get_boolean ("display-notifications"));
            settings.bind ("display-notifications", indicator_notifications, "active", SettingsBindFlags.DEFAULT);

            // Enable battery saver mode
            string[] battery_saver_mode_val = { "Never", "On Threshold", "Always" };
            battery_saver_mode = new ComboRow ("Enable battery saver mode", battery_saver_mode_val, settings.get_int ("battery-saver-mode"));
            battery_saver_mode.changed.connect( () => {
                settings.set_int ("battery-saver-mode", battery_saver_mode.get_combo_value ());
            });

            // Battery charge threshold
            battery_saver_mode_threshold_spin = new SpinRow ("Battery saver mode threshold (%)", 10, 99);
            battery_saver_mode_threshold_spin.set_spin_value (settings.get_int ("battery-saver-mode-threshold"));
            battery_saver_mode_threshold_spin.changed.connect ( () => {
                settings.set_int ("battery-saver-mode-threshold", battery_saver_mode_threshold_spin.get_spin_value ());
            });

            add (indicator);
            add (indicator_connected_only);
            add (indicator_notifications);
            add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            add (battery_saver_mode);
            add (battery_saver_mode_threshold_spin);

        }

    }

}
