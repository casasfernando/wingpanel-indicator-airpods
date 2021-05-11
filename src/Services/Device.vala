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

[DBus (name = "org.bluez.Device1")]
public interface WingpanelAirPods.Device : Object {
    public abstract string[] UUIDs { owned get; }
    public abstract bool blocked { owned get; set; }
    public abstract bool connected { owned get; }
    public abstract bool legacy_pairing { owned get; }
    public abstract bool paired { owned get; }
    public abstract bool trusted { owned get; set; }
    public abstract int16 RSSI { owned get; }
    public abstract ObjectPath adapter { owned get; }
    public abstract string address { owned get; }
    public abstract string alias { owned get; set; }
    public abstract string icon { owned get; }
    public abstract string modalias { owned get; }
    public abstract string name { owned get; }
    public abstract uint16 appearance { owned get; }
    public abstract uint32 @class { owned get; }
}

[DBus (name = "org.freedesktop.DBus.Properties")]
public interface WingpanelAirPods.DBusProperties : Object {
    public signal void properties_changed (string interface, HashTable<string, Variant> changed_properties, string[] invalidated_properties);
}
