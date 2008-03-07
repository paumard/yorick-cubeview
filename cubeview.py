#!/usr/bin/env python
# cubeview.py
# $Id: cubeview.py,v 1.1 2008-03-07 10:03:02 paumard Exp $
# Inspired from yao.py
#     This file is part of Cubeview.
#     Copyright (C) 2007  Thibaut Paumard <paumard@users.sourceforge.net>
#
#     This program is free software; you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation; either version 2 of the License, or
#     (at your option) any later version.
#
#     This program is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License along
#     with this program; if not, write to the Free Software Foundation, Inc.,
#     51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

import gtk
import gtk.glade
import sys
import gobject
import os, fcntl, errno
from time import *

class cubeview:
   
   def destroy(self, wdg, data=None):
      self.py2yo('cv_suspend')
      gtk.main_quit()
      
   def __init__(self,cubeview_glade):
      self.cubeview_glade = cubeview_glade
      self.usercmd = 'STOP'
      
      # callbacks and glade UI
      dic = {
         'cv_handler': self.cv_handler,
         'cv_palette_handler': self.cv_palette_handler,
         'cv_box_handler': self.cv_box_handler,
         'cv_sltype_handler': self.cv_sltype_handler,
         'cv_depth_handler': self.cv_depth_handler,
         'cv_set_sptype': self.cv_set_sptype,
         'cv_set_aperture': self.cv_set_aperture,
         'on_quitter1_activate': self.on_quitter1_activate,
         'on_ouvrir1_activate': self.on_ouvrir1_activate,
         'on_save_selection_as_activate': self.on_save_selection_as_activate,
         'cv_switch_to': self.cv_switch_to,
         'cv_about': self.cv_about,
         'cv_export_window': self.cv_export_window,
         'on_export_plot_or_data': self. on_export_plot_or_data,
         'set_export_formats_list': self.set_export_formats_list,
        }

      self.py2yo('cv_gtk_init')
      self.glade = gtk.glade.XML(self.cubeview_glade)
      self.window = self.glade.get_widget('toolbox')
      self.glade.get_widget('export-data1').set_active(1)
      self.glade.get_widget('export-slice1').set_active(1)
      self.set_export_formats_list(None)
      if (self.window):
         self.window.connect('destroy', self.destroy)
      self.glade.signal_autoconnect(dic)

      # set stdin non blocking, this will prevent readline to block
      fd = sys.stdin.fileno()
      flags = fcntl.fcntl(fd, fcntl.F_GETFL)
      fcntl.fcntl(fd, fcntl.F_SETFL, flags | os.O_NONBLOCK)
      
      # add stdin to the event loop (yorick input pipe by spawn)
      gobject.io_add_watch(sys.stdin,gobject.IO_IN|gobject.IO_HUP,self.yo2py,None)

      # run
      gtk.main()

   def cv_switch_to(self,wdg):
      if wdg.get_name()=="spectrum_properties":
         page=1
      elif wdg.get_name()=="slice_properties":
         page=2
      self.glade.get_widget("notebook1").set_current_page(page)

   def cv_about(self,wdg):
      dialog = self.glade.get_widget('aboutdialog')
      dialog.run()
      dialog.hide()

# File menu hanlders
   
   def on_quitter1_activate(self,wdg):
      self.py2yo('quit')

   def on_ouvrir1_activate(self,wdg):
      chooser = gtk.FileChooserDialog(title='Open 3D FITS File',action=gtk.FILE_CHOOSER_ACTION_OPEN,buttons=(gtk.STOCK_CANCEL,gtk.RESPONSE_CANCEL,gtk.STOCK_OPEN,gtk.RESPONSE_OK))
      filter = gtk.FileFilter()
      filter.add_pattern('*.[fF][iI][tT][sS]')
      filter.add_pattern('*.[fF][iI][tT]')
      filter.add_pattern('*.[fF][iI][tT][sS].gz')
      filter.add_pattern('*.[fF][iI][tT].gz')
      filter.set_name('FITS Files')
      chooser.add_filter(filter)
      res = chooser.run()
      if res == gtk.RESPONSE_OK:
         file=chooser.get_filename()
         self.py2yo('cv_init "'+file+'"')
         self.py2yo('cv_gtk_init')
      chooser.destroy()

   def on_save_selection_as_activate(self,wdg):
      chooser = gtk.FileChooserDialog(title='Save to 3D FITS File',action=gtk.FILE_CHOOSER_ACTION_SAVE,buttons=(gtk.STOCK_CANCEL,gtk.RESPONSE_CANCEL,gtk.STOCK_OPEN,gtk.RESPONSE_OK))
      filter = gtk.FileFilter()
      filter.add_pattern('*.[fF][iI][tT][sS]')
      filter.add_pattern('*.[fF][iI][tT]')
      filter.add_pattern('*.[fF][iI][tT][sS].gz')
      filter.add_pattern('*.[fF][iI][tT].gz')
      filter.set_name('FITS Files')
      chooser.add_filter(filter)
      res = chooser.run()
      if res == gtk.RESPONSE_OK:
         file=chooser.get_filename()
         self.py2yo('cv_save_sel "'+file+'"')
      chooser.destroy()

   ## Export dialog:
   # open export dialog
   def cv_export_window(self,wdg):
      self.py2yo('cv_freemouse')
      chooser = self.glade.get_widget('export-window')
      filter = gtk.FileFilter()
      filter.add_pattern('*')
      filter.set_name('All files')
      chooser.add_filter(filter)
      filter = gtk.FileFilter()
      filter.add_pattern('*.[fF][iI][tT][sS]')
      filter.add_pattern('*.[fF][iI][tT]')
      filter.add_pattern('*.[fF][iI][tT][sS].gz')
      filter.add_pattern('*.[fF][iI][tT].gz')
      filter.set_name('FITS files')
      chooser.add_filter(filter)
      filter = gtk.FileFilter()
      filter.add_pattern('*.txt')
      filter.add_pattern('*.dat')
      filter.add_pattern('*.csv')
      filter.set_name('Text files')
      chooser.add_filter(filter)
      filter = gtk.FileFilter()
      filter.add_pattern('*.jpg')
      filter.add_pattern('*.jpeg')
      filter.add_pattern('*.jfif')
      filter.set_name('JPEG files')
      chooser.add_filter(filter)
      filter = gtk.FileFilter()
      filter.add_pattern('*.png')
      filter.set_name('PNG files')
      chooser.add_filter(filter)
      filter = gtk.FileFilter()
      filter.add_pattern('*.pnm')
      filter.add_pattern('*.ppm')
      filter.set_name('PNM files')
      chooser.add_filter(filter)
      filter = gtk.FileFilter()
      filter.add_pattern('*.eps')
      filter.set_name('EPS files')
      chooser.add_filter(filter)
      filter = gtk.FileFilter()
      filter.add_pattern('*.pdf')
      filter.set_name('PDF files')
      chooser.add_filter(filter)
      res = chooser.run()
      if res:
         savedata = self.glade.get_widget('export-data1').get_active()
         if self.glade.get_widget('export-slice1').get_active():
            what="slice"
         else:
            what="spectrum";
         selection = self.glade.get_widget('export-selection1').get_active()
         format = self.glade.get_widget('export-format1').get_active_text()
         filename = chooser.get_filename()
         if filename:
            self.py2yo('cv_export_misc "'+filename+'" "'+format+'" "'+what+'" '+str(int(savedata))+' '+str(int(selection)))
         else:
            self.py2yo('cv_warning "No filename selected: file not saved"')
      chooser.hide()

   # Plot <-> Data toggle
   def on_export_plot_or_data(self,wdg):
      if self.glade.get_widget('export-data1').get_active():
         self.glade.get_widget('export-selection1').set_sensitive(1);
      else:
         self.glade.get_widget('export-selection1').set_sensitive(0);
      self.set_export_formats_list(wdg)

   def set_export_formats_list(self,wdg):
      if self.glade.get_widget('export-data1').get_active():
         model=gtk.ListStore(str)
         iter=model.append()
         model.set(iter,0,'FITS')
         if self.glade.get_widget('export-slice1').get_active():
            iter=model.append()
            model.set(iter,0,'PNM')
            iter=model.append()
            model.set(iter,0,'PNG')
            iter=model.append()
            model.set(iter,0,'JPEG')
         else:
            iter=model.append()
            model.set(iter,0,'ASCII')
      else:
         model=gtk.ListStore(str)
         iter=model.append()
         model.set(iter,0,'EPS')
         iter=model.append()
         model.set(iter,0,'PDF')
         iter=model.append()
         model.set(iter,0,'PNG')
         iter=model.append()
         model.set(iter,0,'JPEG')
      self.glade.get_widget('export-format1').set_model(model=model)
      self.glade.get_widget('export-format1').set_active(0)
      
   def warning(self,msg):
      mbox = gtk.MessageDialog(self.window, gtk.DIALOG_MODAL, gtk.MESSAGE_WARNING, gtk.BUTTONS_OK, 'Cubeview Warning');
      mbox.format_secondary_markup(msg);
      #,message-type=gtk.MESSAGE_WARNING,buttons=gtk.BUTTONS_OK);
      res=mbox.run();
      mbox.destroy();

# toolbox handlers

   def  cv_handler(self,wdg):
      self.py2yo('cv_freemouse')
      sleep(0.5)
      self.py2yo(wdg.get_name())
         
   def  cv_palette_handler(self,wdg):
      child=wdg.child
      child=wdg.get_child()
      self.py2yo('cv_set_palette "%s"' % child.get_text())
      self.glade.get_widget('Normal').set_active(1)

   def  cv_box_handler(self,wdg):
      self.py2yo('cv_set_' + wdg.get_name() + ' ' + wdg.get_text())
      
   def  cv_sltype_handler(self,wdg):
      if wdg.get_active():
         self.py2yo('cv_sltype "%s"' % wdg.get_name())
      
   def  cv_depth_handler(self,wdg):
      if wdg.get_active():
         self.py2yo('cv_depth "%s"' % wdg.get_name())
         self.glade.get_widget('3 color').set_active(1)
   
      
   def  cv_set_sptype(self,wdg):
      if wdg.get_active():
         self.py2yo('cv_set_sptype "%s"' % wdg.get_name())
      
   def  cv_set_aperture(self,wdg):
      if wdg.get_active():
         self.py2yo('cv_set_aperture "%s"' % wdg.get_name())

   def cv_init(self,sptype,aperture,spsmooth,refwl,
               sltype,slpalette,sldepth,slsmooth,overs):
      self.glade.get_widget(sptype).set_active(1);
      self.glade.get_widget(aperture).set_active(1);
      self.glade.get_widget('refwl').set_text(refwl);
      self.glade.get_widget('spsmooth').set_text(spsmooth);
      entry=self.glade.get_widget('slpalette').child;
      entry.set_text(slpalette);
      self.glade.get_widget(sldepth).set_active(1);
      self.glade.get_widget('slsmooth').set_text(slsmooth);
      self.glade.get_widget('overs').set_text(overs);
      self.glade.get_widget(sltype).set_active(1);
     
   #
   # Yorick to Python Wrapper Functions
   #

   def y_parm_update(self,name,val):
      self.glade.get_widget(name).set_value(val)

   def y_text_parm_update(self,name,txt):
      self.glade.get_widget(name).set_text(txt)

   def y_set_checkbutton(self,name,val):
      self.glade.get_widget(name).set_active(val)
      
   def pyk_error(self,msg):
      dialog = gtk.MessageDialog(type=gtk.MESSAGE_ERROR,buttons=gtk.BUTTONS_OK,message_format=msg)
      dialog.run()
      dialog.destroy()
      
   def pyk_info(self,msg):
      dialog = gtk.MessageDialog(type=gtk.MESSAGE_INFO,buttons=gtk.BUTTONS_OK,message_format=msg)
      dialog.run()
      dialog.destroy()

   def pyk_info_w_markup(self,msg):
      dialog = gtk.MessageDialog(type=gtk.MESSAGE_INFO,buttons=gtk.BUTTONS_OK)
      dialog.set_markup(msg)
#      dialog.set_size_request(600,-1)
      dialog.run()
      dialog.destroy()

   def pyk_warning(self,msg):
      dialog = gtk.MessageDialog(type=gtk.MESSAGE_WARNING,buttons=gtk.BUTTONS_OK,message_format=msg)
      dialog.run()
      dialog.destroy()
      
   def pyk(self,msg):
      # sends string command to yorick
      sys.stdout.write(msg)
      sys.stdout.flush()
      
      # if this flag set, yorick is blocked waiting for tyk_resume
      _tyk_blocked=0
      
   def pyk_sync(self):
      _tyk_blocked=1
      sys.stdout.write('-s+y-n+c-+p-y+k-')
      sys.stdout.flush()
      
   def pyk_resume(self,msg):
      sys.stdout.write('pyk_resume'+msg)
      sys.stdout.flush()
      _tyk_blocked=0
   
   #
   # minimal wrapper for yorick/python communication
   #

   def yo2py_flush(self):
      sys.stdin.flush()
   
   def py2yo(self,msg):
      # sends string command to yorick's eval
      sys.stdout.write(msg+'\n')
      sys.stdout.flush()
   
   def yo2py(self,cb_condition,*args):
      if cb_condition == gobject.IO_HUP:
         raise SystemExit, "lost pipe to yorick"
      # handles string command from yorick
      # note: inidividual message needs to end with /n for proper ungarbling
      while 1:
         try:
            msg = sys.stdin.readline()
            msg = "self."+msg
            exec(msg)
            self.pyk_resume(msg)
         except IOError, e:
            if e.errno == errno.EAGAIN:
               # the pipe's empty, good
               break
            # else bomb out
            raise SystemExit, "yo2py unexpected IOError:" + str(e)
         except Exception, ee:
            raise SystemExit, "yo2py unexpected Exception:" + str(ee)
         return True

   def set_cursor_busy(self,state):
      if state:
         self.window.window.set_cursor(gtk.gdk.Cursor(gtk.gdk.WATCH))
      else:
         self.window.window.set_cursor(gtk.gdk.Cursor(gtk.gdk.LEFT_PTR))
         

if len(sys.argv) != 2:
   print 'Usage: cubeview.py path/to/cubeview.glade'
   raise SystemExit

cubeview_glade = str(sys.argv[1])
top=cubeview(cubeview_glade)
