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
    public class PopoverWidgetRowIconic : Gtk.Grid {
        private Gtk.Image batt_icon;
        private Gtk.Image icon;
        private Gtk.Overlay overlay;
        private Gtk.Label text_label;
        private Gtk.Label value_label;

        public string text_value {
            set { text_label.label = value; }
        }

        public string label_value {
            set { value_label.label = value; }
        }

        public int label_value_width {
            set { value_label.width_chars = value; }
        }

        public string icon_value {
            set { icon.icon_name = value; }
        }

        public string batt_icon_value {
            set { batt_icon.icon_name = value; }
        }

        public PopoverWidgetRowIconic (string batt_icn="", string icn="", string text="", string val="") {
            hexpand = true;
            margin_start = 6;
            margin_top = 6;
            margin_end = 12;
            margin_bottom = 6;
            column_spacing = 3;

            icon = new Gtk.Image.from_icon_name (icn, Gtk.IconSize.DIALOG);
            icon.pixel_size = 48;

            batt_icon = new Gtk.Image.from_icon_name (batt_icn, Gtk.IconSize.LARGE_TOOLBAR);
            batt_icon.pixel_size = 24;
            batt_icon.halign = Gtk.Align.END;
            batt_icon.valign = Gtk.Align.END;

            overlay = new Gtk.Overlay ();
            overlay.margin_end = 3;
            overlay.add (icon);
            overlay.add_overlay (batt_icon);

            text_label = new Gtk.Label (text);
            text_label.halign = Gtk.Align.START;
            text_label.valign = Gtk.Align.END;
            text_label.hexpand = true;
            text_label.margin_start = 9;
            text_label.use_markup = true;
            text_label.set_markup("<b>" + text + "</b>");

            value_label = new Gtk.Label (val);
            value_label.halign = Gtk.Align.START;
            value_label.valign = Gtk.Align.START;
            value_label.margin_start = 9;
            value_label.margin_end = 9;

            // Add battery status icon
            attach (overlay, 0, 0, 1, 2);
            // Add text label
            attach (text_label, 1, 0);
            // Add value label
            attach (value_label, 1, 1);

        }

    }
}
