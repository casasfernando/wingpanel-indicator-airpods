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

[DBus (name = "org.bluez.Adapter1")]
public interface WingpanelAirPods.Adapter : Object {
    public abstract void remove_device (ObjectPath device) throws Error;
    public abstract void set_discovery_filter (HashTable<string, Variant> properties) throws Error;
    public abstract async void start_discovery () throws Error;
    public abstract async void stop_discovery () throws Error;

    public abstract bool discovering { get; }
    public abstract bool powered { get; set; }
}
