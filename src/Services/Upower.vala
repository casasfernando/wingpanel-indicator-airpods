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

[DBus (name = "org.freedesktop.UPower")]
public interface WingpanelAirPods.UPower : Object {
    public abstract ObjectPath[] enumerate_devices() throws Error;
    public abstract bool on_battery { get; }
}

[CCode (type_signature = "u")]
public enum DeviceType {
    UNKNOWN = 0,
    LINE_POWER = 1,
    BATTERY = 2,
    UPS = 3,
    MONITOR = 4,
    MOUSE = 5,
    KEYBOARD = 6,
    PDA = 7,
    PHONE = 8;
}
[DBus (name = "org.freedesktop.UPower.Device")]
public interface WingpanelAirPods.UPowerDevice : Object {
    public abstract double energy { get; }
    public abstract double energy_empty { get; }
    public abstract double energy_full { get; }
    public abstract double percentage { get; }
    [DBus (name = "Type")]
    public abstract DeviceType device_type { get; }
}
