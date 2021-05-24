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

[DBus (name="org.mpris.MediaPlayer2.Player")]
public interface WingpanelAirPods.MediaPlayer : Object {
    public abstract void next () throws Error;
    public abstract void previous () throws Error;
    public abstract void pause () throws Error;
    public abstract void play_pause () throws Error;
    public abstract void stop () throws Error;
    public abstract void play () throws Error;
    public abstract string playback_status { owned get; }
    public abstract HashTable<string,Variant> metadata { owned get; }
    public abstract bool can_go_next { get; }
    public abstract bool can_go_previous { get; }
    public abstract bool can_play { get; }
    public abstract bool can_pause { get; }
}
