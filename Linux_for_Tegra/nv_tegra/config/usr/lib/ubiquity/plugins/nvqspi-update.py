#!/usr/bin/env python

# Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
#
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

import os
import subprocess
from ubiquity import plugin

# Plugin settings
NAME = 'nv-qspi-update'
AFTER = 'nv-swap'
WEIGHT = 30

class PageGtk(plugin.PluginUI):
    plugin_title = 'ubiquity/text/nv_qspi_update_label'

    def __init__(self, controller, *args, **kwargs):
        super(PageGtk, self).__init__(self, *args, **kwargs)
        self.script = '/usr/lib/nvidia/qspi-update/nvqspi-update.sh'

        if not self.check_pre_req():
            return

        from gi.repository import Gtk

        container = Gtk.VBox(spacing=20)
        container.set_border_width(20)
        container.set_homogeneous(False)

        label_description = Gtk.Label(
                'This system has the new QSPI image (MaxSPI), we will remove the un-used bootloader partitions on your\n' +
                'SD card to help you save some space. After this one time action completes, the image on this SD card will\n' +
                'no longer work with the older QSPI image from JP4.4 and older. If you do not want to proceed, please power\n' +
                'down your system and use SDK Manager to re-flash your Jetson with JP4.4 or older releases.\n' +
                '\n' +
                'Update QSPI process will take about 2 mins, press [Continue] and wait for the completion of QSPI update')
        label_description.set_justify(Gtk.Justification.LEFT)
        label_description.show()
        container.pack_start(label_description, False, False, 0)

        self.page = container
        self.controller = controller
        self.plugin_widgets = self.page

    def plugin_on_next_clicked(self):
        subprocess.check_output([self.script, '-u'], universal_newlines=True).strip()

    def check_pre_req(self):
        if not os.path.exists(self.script):
            return False

        # Query whether current platform is supported to update QSPI
        support_update = subprocess.check_output(
                [self.script, '-c'], universal_newlines=True).strip()
        if support_update == 'false':
            return False

        return True

class PageDebconf(plugin.Plugin):
    plugin_title = 'ubiquity/text/nv_qspi_update_label'

    def __init__(self, controller, *args, **kwargs):
        super(PageDebconf, self).__init__(self, *args, **kwargs)
        self.controller = controller

class Page(plugin.Plugin):
    def prepare(self, unfiltered=False):
        if os.environ.get('UBIQUITY_FRONTEND', None) == 'debconf_ui':
            nv_qspi_update_script = '/usr/lib/nvidia/qspi-update/nvqspi-update-query'
            return [nv_qspi_update_script]
        return
