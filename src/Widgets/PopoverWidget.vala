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
    public class PopoverWidget : Gtk.Grid {

        private PopoverWidgetRowIconic left_pod;
        private PopoverWidgetRowIconic right_pod;
        private PopoverWidgetRowIconic pods_case;

        private Gtk.Grid airpods_disconnected;
        private Gtk.Image airpods_disconnected_icon;
        private Gtk.Label airpods_disconnected_text_label;
        private Gtk.Label airpods_disconnected_value_label;

        private Wingpanel.Widgets.Switch indicator_battery;

        public unowned Settings settings { get; construct set; }

        public PopoverWidget (Settings settings) {
            Object (settings: settings);
        }

        construct {
            orientation = Gtk.Orientation.VERTICAL;
            column_spacing = 4;

            left_pod = new PopoverWidgetRowIconic ("battery-missing", "airpods-left-symbolic", "Left AirPod", "Not Connected");
            right_pod = new PopoverWidgetRowIconic ("battery-missing", "airpods-right-symbolic", "Right AirPod", "Not Connected");
            pods_case = new PopoverWidgetRowIconic ("battery-missing", "airpods-case-symbolic", "AirPods Case", "Not Connected");

            airpods_disconnected = new Gtk.Grid ();
            airpods_disconnected.hexpand = true;
            airpods_disconnected.margin_start = 6;
            airpods_disconnected.margin_end = 12;
            airpods_disconnected.column_spacing = 3;

            airpods_disconnected_icon = new Gtk.Image.from_icon_name ("airpods-symbolic", Gtk.IconSize.DIALOG);
            airpods_disconnected_icon.pixel_size = 48;
            airpods_disconnected_icon.margin_end = 3;

            airpods_disconnected_text_label = new Gtk.Label ("AirPods");
            airpods_disconnected_text_label.halign = Gtk.Align.START;
            airpods_disconnected_text_label.valign = Gtk.Align.END;
            airpods_disconnected_text_label.hexpand = true;
            airpods_disconnected_text_label.margin_start = 9;
            airpods_disconnected_text_label.get_style_context ().add_class (Granite.STYLE_CLASS_H4_LABEL);

            airpods_disconnected_value_label = new Gtk.Label ("Not Connected");
            airpods_disconnected_value_label.halign = Gtk.Align.START;
            airpods_disconnected_value_label.valign = Gtk.Align.START;
            airpods_disconnected_value_label.margin_start = 9;
            airpods_disconnected_value_label.margin_end = 9;

            // Add element icon
            airpods_disconnected.attach (airpods_disconnected_icon, 0, 0, 1, 2);
            // Add text label
            airpods_disconnected.attach (airpods_disconnected_text_label, 1, 0);
            // Add value label
            airpods_disconnected.attach (airpods_disconnected_value_label, 1, 1);

            // Enable indicator battery information switch
            indicator_battery = new Wingpanel.Widgets.Switch ("Show percentage", settings.get_boolean ("display-indicator-battery"));
            settings.bind ("display-indicator-battery", indicator_battery.get_switch (), "active", SettingsBindFlags.DEFAULT);

            var settings_button = new Gtk.ModelButton ();
            settings_button.text = _ ("Open Settings...");
            /*
            var settings_button = new Gtk.Button.from_icon_name ("preferences-system-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            settings_button.always_show_image = true;
            settings_button.label = "Open Settings...";
            settings_button.relief = Gtk.ReliefStyle.NONE;
            */
            settings_button.clicked.connect (open_settings);

            var airpods_name_label = new Gtk.Label (settings.get_string ("airpods-name"));
            airpods_name_label.halign = Gtk.Align.CENTER;
            airpods_name_label.hexpand = true;
            airpods_name_label.margin_start = 9;
            airpods_name_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

            add (airpods_name_label);
            add (left_pod);
            update_left_pod_visibility ();
            add (right_pod);
            update_right_pod_visibility ();
            add (pods_case);
            update_pods_case_visibility ();
            add (airpods_disconnected);
            update_airpods_disconnected_visibility ();
            add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
            add (indicator_battery);
            add (settings_button);
        }

        private void open_settings () {
            try {
                var appinfo = AppInfo.create_from_commandline (
                    "com.github.casasfernando.wingpanel-indicator-airpods", null, AppInfoCreateFlags.NONE
                    );
                appinfo.launch (null, null);
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }

        public void set_widget_visible (Gtk.Widget widget, bool visible) {
            widget.no_show_all = !visible;
            widget.visible = visible;
        }

        public void update_left_pod_visibility () {
            if (settings.get_int64 ("airpods-status-batt-l") != 15) {
                set_widget_visible (left_pod, true);
            } else {
                set_widget_visible (left_pod, false);
            }
        }

        public void update_right_pod_visibility () {
            if (settings.get_int64 ("airpods-status-batt-r") != 15) {
                set_widget_visible (right_pod, true);
            } else {
                set_widget_visible (right_pod, false);
            }
        }

        public void update_pods_case_visibility () {
            if (settings.get_int64 ("airpods-status-batt-case") != 15) {
                set_widget_visible (pods_case, true);
            } else {
                set_widget_visible (pods_case, false);
            }
        }

        public void update_airpods_disconnected_visibility () {
            if (settings.get_int64 ("airpods-status-batt-l") == 15 && settings.get_int64 ("airpods-status-batt-r") == 15 && settings.get_int64 ("airpods-status-batt-case") == 15) {
                set_widget_visible (airpods_disconnected, true);
            } else {
                set_widget_visible (airpods_disconnected, false);
            }
        }

        public void update_left_pod (string icn, string val) {
            left_pod.batt_icon_value = icn;
            left_pod.label_value = val;
        }

        public void update_right_pod (string icn, string val) {
            right_pod.batt_icon_value = icn;
            right_pod.label_value = val;
        }

        public void update_pods_case (string icn, string val) {
            pods_case.batt_icon_value = icn;
            pods_case.label_value = val;
        }

    }

}