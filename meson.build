project('com.github.casasfernando.wingpanel-indicator-airpods', 'vala', 'c')

gnome = import('gnome')
i18n = import('i18n')

add_project_arguments(['--vapidir', join_paths(meson.current_source_dir(), 'vapi')], language: 'vala')
add_global_arguments('-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name()), language:'c')

# common dirs
prefix = get_option('prefix')
datadir = join_paths(prefix, get_option('datadir'))
libdir = join_paths(prefix, get_option('libdir'))
icondir = join_paths(datadir, 'icons', 'hicolor')

# deps
wingpanel = dependency('wingpanel-2.0')

icons_gresource = gnome.compile_resources(
    'gresource_icons',
    'data/icons/icons.indicator.gresource.xml',
    source_dir: 'data/icons',
    c_name: 'as'
)

config_data = configuration_data()
config_data.set_quoted('GETTEXT_PACKAGE', meson.project_name())

configure_file(output: 'config.h', configuration: config_data)
config_h_dir = include_directories('.')

c_args = [
  '-include', 'config.h',
  '-w',
]

executable(
    meson.project_name(),
    icons_gresource,
    'src/Application.vala',
    'src/MainWindow.vala',
    'src/Widgets/ComboRow.vala',
    'src/Widgets/SpinRow.vala',
    'src/Widgets/Toggles.vala',
    c_args: c_args,
    dependencies: [
        dependency('gee-0.8'),
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        wingpanel,
        meson.get_compiler('c').find_library('m', required : false),
        meson.get_compiler('vala').find_library('posix')
    ],
    install: true
)

shared_module(
    'wingpanel-indicator-airpods',
    'src/Indicator.vala',
    'src/Services/Airpods.vala',
    'src/Services/Bluez.vala',
    'src/Services/Dbus.vala',
    'src/Services/Mpris.vala',
    'src/Services/Upower.vala',
    'src/Widgets/DisplayWidget.vala',
    'src/Widgets/IndicatorWidget.vala',
    'src/Widgets/PopoverWidget.vala',
    'src/Widgets/PopoverWidgetRowIconic.vala',
    icons_gresource,
    c_args: c_args,
    dependencies: [
        dependency('gee-0.8'),
        dependency('glib-2.0'),
        dependency('gobject-2.0'),
        dependency('granite'),
        dependency('gtk+-3.0'),
        dependency('libnotify'),
        wingpanel,
    ],
    install: true,
    install_dir : wingpanel.get_pkgconfig_variable('indicatorsdir', define_variable: ['libdir', libdir]),
)

subdir('data')
meson.add_install_script('meson/post_install.py')
