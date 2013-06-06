/*
   CUBEVIEW.I
   Routines to visualize 3D data, particularly spectroimaging data.

    Copyright (C) 2003-2013  Thibaut Paumard <paumard@users.sourceforge.net>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
*/
extern cv_ui;
/* DOCUMENT cv_ui = "gtk"
         or cv_ui = "tws"
         or cv_ui = "text"
   Which ui should cubeview use? This is the initial default, the last
   one used is remembered for the duration of the session.
*/
if (is_void(cv_ui)) cv_ui="gtk"; // or tws, or text

// Standard include files
#include "style.i"
#include "spline.i"
#include "fits.i"
#include "ieee.i"
#include "gauss.i"
#include "pathfun.i"
#include "pnm.i"

// from yutils: is_numerical
#include "plot.i"
#include "utils.i"
#include "doppler.i"
#include "tws.i"
#include "graphk.i"

// bundled with cubeview
#include "bear.i"

// string.i needs to be included _after_ utils.i to get he right strchr
#include "string.i"

// A few other files may be required for certain tasks:
// Standard: fits.i, string.i, pnm.i
// Non standard: gy_gtk.i, coords.i

CUBEVIEW_VERSION="2.0~git";

func cv_toolbox_state(wgd, evt, udata)
{
  extern cv_nodraw;
  if (_cvgy.realized) return 0;
  _cvgy, realize=1;
  cv_nodraw=0;
  //  gywindow, cv_interns.sp_wid,width=0,height=0,style="work.gs",
  //  on_realize=cv_spdraw;
  //gywindow, cv_interns.slice_wid,width=0,height=0,style="work.gs",
  //  on_realize=cv_sldraw_first;
  return 0;
}

func cv_sldraw_first(void)
{
  cv_sldraw;
  cv_sllims;
  cv_vpaspect,cv_interns.xyaspect;
}

func cv_gtk(void)
{
  require, "gy_gtk.i";
  extern _cvgy, cv_interns, gy_gtk_on_main_quit;
  if (is_void(_cvgy)) _cvgy=save();
  if (is_void(cv_interns))
    cv_interns=CV_Interns(slice_wid=cv_defaults.slice_wid,
                          sp_wid=cv_defaults.sp_wid, cmd_wid=cv_defaults.cmd_wid,
                          depth=cv_defaults.depth, origin=cv_defaults.origin,
                          scale=cv_defaults.scale, overs=cv_defaults.overs,
                          slboxcol=cv_defaults.slboxcol,zwlwise=cv_defaults.zwlwise,
                          sltype=cv_defaults.sltype, slpalette=cv_defaults.slpalette,
                          slinterp=cv_defaults.slinterp,refwl=cv_defaults.refwl,
                          zaxistype=cv_defaults.zaxistype,vlsr=cv_defaults.vlsr,
                          pixel=cv_defaults.pixel,hook=cv_defaults.hook,
                          spkeywords=cv_defaults.spkeywords,
                          aperture_type=cv_defaults.aperture_type,
                          blank=cv_defaults.blank,xyaspect=cv_defaults.xyaspect);
  
  Gtk=gy.require("Gtk", "3.0");
  if (cv_stand_alone) {
    gy_gtk_on_main_quit=cv_quit;
    noop, gy.GLib.set_prgname("Cubeview");
    noop, gy.GLib.set_application_name("Cubeview");
  }
  noop, Gtk.init(0,);
  gy_setlocale;
  save, _cvgy, builder = gy_gtk_builder("cubeview.glade");

  // Set widget initial values from cv_interns
  sldepth = pr1(cv_interns.depth)+"bit";
  noop, _cvgy.builder.get_object(cv_interns.zaxistype).set_active(1);
  noop, _cvgy.builder.get_object(cv_interns.aperture_type).set_active(1);
  noop, _cvgy.builder.get_object("refwl").set_value(cv_interns.refwl);
  noop, _cvgy.builder.get_object("spsmooth").set_value(cv_interns.spsmooth);
  noop, _cvgy.builder.get_object(sldepth).set_active(1);
  noop, _cvgy.builder.get_object(cv_interns.sltype).set_active(1);
  noop, _cvgy.builder.get_object("slsmooth").set_value(cv_interns.slsmooth);
  noop, _cvgy.builder.get_object("sloversampling").set_value(cv_interns.overs);
  
  gy_signal_connect, _cvgy.builder;
  
  gy_gtk_ycmd_connect, _cvgy.builder.get_object("ycmd");
  mhbox = _cvgy.builder.get_object("ywindows");
  yid = [];
  if (!is_void(cv_cube)) on_realize=cv_spdraw; else on_realize=[];
  win = gy_gtk_ywindow(yid, style="work.gs", width=450, height=450,
                       on_realize=on_realize, grab=1);
  noop, mhbox.pack1(win, 1, 1);
  cv_interns.sp_wid = yid;
  yid = [];
  if (!is_void(cv_cube)) on_realize=cv_sldraw_first; else on_realize=[];
  win = gy_gtk_ywindow(yid, style="work.gs", width=450, height=450,
                       on_realize=on_realize, grab=1);
  noop, mhbox.pack2(win, 1, 1);

  noop, mhbox.set_size_request(900,0);
  cv_interns.slice_wid = yid;
  save, _cvgy, toolbox=_cvgy.builder.get_object("toolbox"), realized=0;
  iconf = find_in_path("cubeview-big.png", takefirst=1, path=Y_DATA);
  if (iconf) {
    icon = gy.GdkPixbuf.Pixbuf.new_from_file(iconf);
    noop, _cvgy.toolbox.set_icon(icon);
    _cvgy, icon=icon;
  }

  noop, _cvgy.builder.get_object("slsel").set_active(1);
  noop, _cvgy.builder.get_object("spsel").set_active(1);

  gy_gtk_main, _cvgy.toolbox;
}

func cv_quit(void)
{
  winkill, cv_interns.slice_wid;
  winkill, cv_interns.sp_wid;
  quit;
  error, "Error triggered to exit Cubeview in batch mode. Should not happen.";
}

func cv_open(wdg, udata) {
  Gtk=gy.Gtk;
  chooser = Gtk.FileChooserDialog();
  noop, chooser.add_button(Gtk.STOCK_OPEN, Gtk.ResponseType.ok);
  noop, chooser.add_button(Gtk.STOCK_CANCEL, Gtk.ResponseType.cancel);
  fcfc = Gtk.FileChooser(chooser);
  noop, fcfc.set_action(Gtk.FileChooserAction.open);
  noop, fcfc.set_do_overwrite_confirmation(1);
  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[fF][iI][tT][sS]");
  noop, filter.add_pattern("*.[fF][iI][tT]");
  noop, filter.add_pattern("*.[fF][iI][tT][sS].gz");
  noop, filter.add_pattern("*.[fF][iI][tT].gz");
  noop, filter.set_name("FITS files");
  noop, fcfc.add_filter(filter);
  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*");
  noop, filter.set_name("All files");
  noop, fcfc.add_filter(filter);
  noop, chooser.show_all();
  answer = chooser.run();
  noop,chooser.hide();
  if (answer==gy.Gtk.ResponseType.ok) {
    file=Gtk.FileChooser(chooser).get_filename();
    cv_init, file, slice_wid=cv_interns.slice_wid, sp_wid=cv_interns.sp_wid;
    cv_spdraw;
    cv_sldraw_first;
  }
  noop, chooser.destroy();
}

func cv_save(wdg, udata) {
  Gtk=gy.Gtk;
  chooser = Gtk.FileChooserDialog();
  noop, chooser.add_button(Gtk.STOCK_SAVE, Gtk.ResponseType.ok);
  noop, chooser.add_button(Gtk.STOCK_CANCEL, Gtk.ResponseType.cancel);
  fcfc = Gtk.FileChooser(chooser);
  noop, fcfc.set_action(Gtk.FileChooserAction.save);
  noop, fcfc.set_do_overwrite_confirmation(1);
  noop, fcfc.set_create_folders(1);
  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[fF][iI][tT][sS]");
  noop, filter.add_pattern("*.[fF][iI][tT]");
  noop, filter.add_pattern("*.[fF][iI][tT][sS].gz");
  noop, filter.add_pattern("*.[fF][iI][tT].gz");
  noop, filter.set_name("FITS files");
  noop, fcfc.add_filter(filter);
  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*");
  noop, filter.set_name("All files");
  noop, fcfc.add_filter(filter);
  noop, chooser.show_all();
  answer = chooser.run();
  noop,chooser.hide();
  if (answer==gy.Gtk.ResponseType.ok) {
    file=Gtk.FileChooser(chooser).get_filename();
    cv_save_sel, file;
  }
  noop, chooser.destroy();
}

func cv_export(wdg, udata) {
  Gtk=gy.Gtk;
  chooser = Gtk.FileChooserDialog();
  noop, chooser.add_button(Gtk.STOCK_SAVE, Gtk.ResponseType.ok);
  noop, chooser.add_button(Gtk.STOCK_CANCEL, Gtk.ResponseType.cancel);
  grid = Gtk.Grid();
  noop, grid.set_column_homogeneous(1);
  noop, chooser.get_content_area().pack_start(grid, 0,0,0);
  
  slice = Gtk.RadioButton.new_with_label(,"Slice");
  spectrum = Gtk.RadioButton.new_with_label(slice.get_group(),"Spectrum");
  noop, grid.attach(slice, 1, 1, 1, 1);
  noop, grid.attach(spectrum, 1, 2, 1, 1);
  
  data = Gtk.RadioButton.new_with_label(,"Data");
  plot = Gtk.RadioButton.new_with_label(data.get_group(),"Plot");
  noop, grid.attach(data, 2, 1, 1, 1);
  noop, grid.attach(plot, 2, 2, 1, 1);

  sel = Gtk.CheckButton.new_with_label("Selection only");
  noop, grid.attach(sel, 3, 1, 1, 1);
  
  fcfc = Gtk.FileChooser(chooser);
  noop, fcfc.set_action(Gtk.FileChooserAction.save);
  noop, fcfc.set_do_overwrite_confirmation(1);
  noop, fcfc.set_create_folders(1);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[fF][iI][tT][sS]");
  noop, filter.add_pattern("*.[fF][iI][tT]");
  noop, filter.add_pattern("*.[tT][xX][tT]");
  noop, filter.add_pattern("*.[cC][sS][vV]");
  noop, filter.add_pattern("*.[dD][aA][tT]");
  noop, filter.add_pattern("*.[pP][dD][fF]");
  noop, filter.add_pattern("*.[eE][pP][sS]");
  noop, filter.add_pattern("*.[jJ][pP][eE][gG]");
  noop, filter.add_pattern("*.[jJ][pP][gG]");
  noop, filter.add_pattern("*.[jJ][fF][iI][fF]");
  noop, filter.add_pattern("*.[pP][nN][gG]");
  noop, filter.add_pattern("*.[pP][nN][mM]");
  noop, filter.add_pattern("*.[pP][pP][mM]");
  noop, filter.set_name("All supported files");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[fF][iI][tT][sS]");
  noop, filter.add_pattern("*.[fF][iI][tT]");
  noop, filter.set_name("FITS files");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[tT][xX][tT]");
  noop, filter.add_pattern("*.[cC][sS][vV]");
  noop, filter.add_pattern("*.[dD][aA][tT]");
  noop, filter.set_name("Text files");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[pP][dD][fF]");
  noop, filter.set_name("PDF documents");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[eE][pP][sS]");
  noop, filter.set_name("EPS documents");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[jJ][pP][eE][gG]");
  noop, filter.add_pattern("*.[jJ][pP][gG]");
  noop, filter.add_pattern("*.[jJ][fF][iI][fF]");
  noop, filter.set_name("JPEG images");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[pP][nN][gG]");
  noop, filter.set_name("PNG images");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*.[pP][nN][mM]");
  noop, filter.add_pattern("*.[pP][pP][mM]");
  noop, filter.set_name("PNM images");
  noop, fcfc.add_filter(filter);

  filter = Gtk.FileFilter();
  noop, filter.add_pattern("*");
  noop, filter.set_name("All files");
  noop, fcfc.add_filter(filter);
  
  noop, chooser.show_all();
  answer = chooser.run();
  noop,chooser.hide();
  if (answer==gy.Gtk.ResponseType.ok) {
    file=Gtk.FileChooser(chooser).get_filename();
    savedata = data.get_active();
    if (slice.get_active()) what="slice";
    selection=sel.get_active();
    cv_export_misc, file, [], what, savedata, selection;
  }
  noop, chooser.destroy();
}

func cv_about(wdg, udata)
{
  Gtk=gy.require("Gtk", "3.0");
  dialog = Gtk.AboutDialog();
  noop, dialog.set_program_name("Cubeview");
  noop, dialog.set_version(CUBEVIEW_VERSION);
  noop, dialog.set_logo(icon);
  noop, dialog.set_copyright("Copyright © 2003-2013 Thibaut Paumard");
  noop, dialog.set_license_type(Gtk.License.gpl_2_0);
  noop, dialog.run();
  noop, dialog.destroy();
}

func cv_wakeup {resume;}

func cv_valids(x,y,z){
    if (cv_interns.isbig) {
        //did not cache.
        blank=cv_interns.blank;

        if (is_real(cv_cube))
          valids=ieee_test(cv_cube(x,y,z))==0; else
            valids=array(char(1),dimsof(cv_cube(x,y,z)));
        // We no the cube is big, don't make several copies of valids

        if (is_scalar(z)) {
          if (ieee_test(blank)==0) valids &= cv_cube(x,y,z)!=blank;
          return valids;
        }
        if (is_void(z)) {
          z_ind=indgen(dimsof(cv_cube)(4));
        } else if (is_range(z)) {
            z_ind=indgen(z);
        } else {
            // else we assume z is an array of indices.
            z_ind=z;
        }
        nz=numberof(z_ind);
        if (ieee_test(blank)==0) {
            for (k=1;k<=nz;k++)
              valids(..,z_ind(k)) &= (*cv_interns)(x,y,z_ind(k))!=blank;
        }
        return valids;
    }
    return cv_valids(x,y,z);

}

func cv_freeylimits(wdg, udata) {
/* DOCUMENT cv_freeylimits
   
    Frees  Y limits,  hence the  name...  Indeed,  calls LIMITS  to  uset every
    limits, then sets back X limits. Very useful if you've set limits using the
    mouse and want to explore data only within the selected range.

    Normally called through cubeview's "Spectrum Y limits" button.
*/
  extern cv_nodraw;
  if (cv_nodraw) return;
  cv_spwin;
  oldlimits=limits();
  limits;
  limits,oldlimits(1),oldlimits(2);
}


struct CV_Interns {
/* DOCUMENT CV_Interns: structure type use internally by cubeview.
 {

 pointer slice; //  pointer to the current slice, either  indexed color or RGB,
                // so either NxM or 3xNxM.
 pointer spectrum; // pointer to the current spectrum, of size P.
 pointer zaxis;    // spectral axis, in pixels
 pointer waxis;    // wavelength spectral axis, in microns
 pointer faxis;    // frequency spectral axis, in cm-1
 pointer vaxis;    // velocity spectral axis, in km/s
 pointer  root;  //  pointer  to  cubeview's TWS_Root  widget.  See  tws.i  and
                 //  tws_root.i
 long slice_wid,sp_wid,cmd_wid; // Cubeview windows identifiers
 long sllims(2); // indices of the first and last z-planes of the current slice
 long depth; // depth of the slice image in 3 color mode: 8 or 24
 long big_size; // if cubes has more voxels than that, sopme treatements will
                // be memory-optimized.
 double spbox(4); // integer pixel coordinates of the spectrum aperture if rectangular
                   or square, center x, center y, radius and nothing if circular
 double cmin,cmax; // lower and upper cut for displaying the slice
 double origin(3);  // 3D  position of  the data cell  (1,1,1) in  you prefered
                    //  coordinate system
 double  scale(3);  //  scales  of  the data  in  the  three
                    //  dimensions
 double slpos(4); // "real world" coordinates of the 4 corners of the field
 double overs; // oversampling factor to display the slice
 double refwl; // reference wavelength in microns for conversion into velocity
 double vlsr; // true "systemic" velocity in the local standard of rest if its observed velocity is 0.
 double spsmooth ; // smoothing box for the displayed spectrum
 double slsmooth ; // smoothing box for the displayed slice
 char slboxcol;  // color index  to draw the  box inicating the  slice bandpass
                 //  when in normal mode
 char zwlwise; // 0 zaxis is frequency-wise, 1 if it is wavelength-wise
 string sltype; //  String containing the type of slice,  either "Normal" or "3
                //  color". Used by most cv_ routines that access the slice.
 string slpalette; // palette to use for the slice when in normal mode
 string zaxistype; // type of Z-axis to use: "PIX", "WAVE", "FREQ" or "VELOCITY"
 string slinterp; // use interp or spline to interpolate? spline is much better
                  // and...  slower.  Should not be a problem,  except  if  you
                  // work  on really big data.
 string aperture_type; // rectangular, square, circular
 string hook; // name of a function  to call from time to times (basically each
              // time a window  is updated). Format not well defined  yet. One
              // (or several?) general interest hook is provided. See cv_*_hook.
 GraphK spkeywords; // graphic keywords to plot the spectra. See graphk.i.
 double xyaspect; // aspect ratio X/Y of the viewport in the slice window.
                  // by default, depends on the dimensions of the data.
                  // Set to 0 for this behavior, or to a scalar.
 }

    SEE ALSO: cv_interns, cubeview, cv_library
*/
  pointer slice,spectrum,zaxis,waxis,faxis,vaxis,root,popup,header;
  long slice_wid,sp_wid,cmd_wid,sllims(2),depth,big_size;
  double cmin,cmax,origin(3),scale(3),slpos(4),overs,refwl,vlsr,spsmooth,slsmooth,spbox(4),blank,xyaspect;
  char slboxcol,zwlwise,pixel,isbig,mouselock;
  string sltype,slpalette,slinterp,zaxistype,hook,aperture_type;
  GraphK spkeywords; // see graphk.i
}

extern cv_interns, cv_cube, cv_valids, cv_fh;
/* DOCUMENT extern cv_cube, cv_interns

   cv_cube is an external variable holding the data cube being viewed
   in Cubeview.
   
   cv_interns is a structure of type CV_Interns, containing all other
   variables shared by Cubeview routines.

   cv_valids is a mask indicating which cells in cv_cube are valid
   data. It is used to speed up various treatments, unless the cube
   "isbig".
   
   The most usefull items for the user are .slice and .spectrum,
   pointers to eponym arrays.  .spbox is a 4 elements array containing
   the coordinates of the corners of the region defining the spectrum
   aperture, and likewise .sllims contains the limits of the spectral
   region defining the slice.  .slice is either a NxM indexed color
   array, or a 3xNxM RGB array.

   SEE ALSO: CV_Interns, cubeview, cv_library
*/

struct CV_Defaults
/* DOCUMENT CV_Defaults

   Structure  to handle  defaults for  cubeview. The  members are  the  ones of
   CV_Interns for  which setting a  default makes sense. The  external variable
   cv_defaults is normally  the only variable of type  CV_Defaults. You may set
   defaults  by accessing  this  variable,  that is  erased  when you  #include
   cubeview.

   {
     long slice_wid,sp_wid,cmd_wid,depth;
     double origin(3),scale(3),overs,vlsr,spsmooth,slsmooth,blank,xyaspect;
     char slboxcol,zwlwise,pixel;
     string sltype,slpalette,slinterp,hook,aperture_type;
     GraphK spkeywords;
   }

   SEE ALSO: cv_defaults, cv_library
*/
{
  long slice_wid,sp_wid,cmd_wid,depth,big_size;
  double origin(3),scale(3),overs,refwl,vlsr,spsmooth,slsmooth,blank,xyaspect;
  char slboxcol,zwlwise,pixel;
  string sltype,slpalette,slinterp,zaxistype,hook,aperture_type;
  GraphK spkeywords;
}

// Here I define the defaults
extern cv_defaults;
/* DOCUMENT cv_defaults

     Instance of CV_Defaults defining defaults for Cubeview.

     cv_defaults=CV_Defaults(slice_wid=0,
                             sp_wid=1,
                             cmd_wid=2,
                             depth=24,
                             origin=[1,1,1],
                             scale=[1,1,1],
                             overs=1,
                             slboxcol=248,
                             zwlwise=0,
                             sltype="Normal",
                             slpalette="stern.gp",
                             slinterp="spline",
                             zaxistype="PIX",
                             refwl=2.166120,
                             pixel=1);

   SEE ALSO: CV_Defaults, cubeview, cv_library
*/
if (is_void(defaults)) {
  junk=[0.];
  ieee_set,junk,2;
  cv_defaults=CV_Defaults(slice_wid=0,sp_wid=1,cmd_wid=2,depth=24,
                            origin=[1,1,2],scale=[1,1,1e-3],overs=1,
                            slboxcol=248,zwlwise=0,sltype="Normal",
                            slpalette="stern.gp",slinterp="spline",
                            zaxistype="WAVE",refwl=2.166120,pixel=1,
                            aperture_type="circular",big_size=1e8,
                            blank=junk(1),spkeywords=GraphK(marks=&long(0)));
 }

func cv_init(data,slice_wid=,sp_wid=,cmd_wid=,origin=,scale=,depth=,overs=,
             slboxcol=,sltype=,slpalette=,slinterp=,zwlwise=,refwl=,
             waxis=,faxis=,vaxis=,zaxistype=,vlsr=,pixel=,hook=,spkeywords=,
             postinit=,big_size=,isbig=,blank=,xyaspect=)
/* DOCUMENT  cv_init,"file.fits"  or  cv_init,3D_array

     It's  probably better  not to  call directly  CV_INIT and  let  the almost
     graphical tool CUBEVIEW do it.  Initiates Cubeview.  If called with a fits
     file name, includes  "fits.i" and reads the file.  Feeds  all items of the
     external  variable CV_INTERNS,  and displays  a  first slice  and a  first
     spectrum.  After, you could use cv_spsel and cv_slsel.

     Cubeview has a kind of graphical  user interface that can be launched with
     "cubeview,data", or "cv_resume" once CV_INIT has been called.

     cv_init takes as keyword any member of CV_Defaults, override the defaults.

     In  addition to this,  cv_init will  include any  .i file  specified as
     POSTINIT keyword.

   SEE ALSO: cubeview, cv_library, cv_defaults
*/
{
  local slice_wid,sp_wid,cmd_wid,origin,scale,depth,overs,slbox,sltype,slpalette;
  extern cv_interns,cv_defaults,cv_cube,cv_valids, __cv_palette;
  cv_interns=CV_Interns(slice_wid=cv_defaults.slice_wid,
                        sp_wid=cv_defaults.sp_wid, cmd_wid=cv_defaults.cmd_wid,
                        depth=cv_defaults.depth, origin=cv_defaults.origin,
                        scale=cv_defaults.scale, overs=cv_defaults.overs,
                        slboxcol=cv_defaults.slboxcol,zwlwise=cv_defaults.zwlwise,
                        sltype=cv_defaults.sltype, slpalette=cv_defaults.slpalette,
                        slinterp=cv_defaults.slinterp,refwl=cv_defaults.refwl,
                        zaxistype=cv_defaults.zaxistype,vlsr=cv_defaults.vlsr,
                        pixel=cv_defaults.pixel,hook=cv_defaults.hook,
                        spkeywords=cv_defaults.spkeywords,
                        aperture_type=cv_defaults.aperture_type,
                        blank=cv_defaults.blank,xyaspect=cv_defaults.xyaspect);
  // Read data and coordinate system if available
  if (is_void(data)) {
    require,"ytk.i";
    ftypes="{{{FITS Files} {.fits .fit .FIT .fts .FITS .FTS}} {{All files} {*}}}";
    data=get_openfn(filetypes=ftypes);    
  }
  // Keywords overwritting defaults
  if (!is_void(pixel)) cv_interns.pixel=pixel;
  else pixel=cv_interns.pixel;
  if (typeof(data)=="string") {
    pos=strchr(data,'.',last=1);
    if (pos>0) {
      suffix=strpart(data,pos:);
      if (suffix==".gz") {
        system,"gzip -d < "+data+" > cubeview.tmp.fits";
        cv_cube=double(fits_read("cubeview.tmp.fits",cv_fh, hdu=cv_hdu));
        system,"rm -f cubeview.tmp.fits";
      } else {
        cv_cube=double(fits_read(data,cv_fh, hdu=cv_hdu));
      }
    } else {
      cv_cube=double(fits_read(data,cv_fh, hdu=cv_hdu));
    }
    BLANK = fits_get(cv_fh,"BLANK");
    if (is_numerical(BLANK)) cv_interns.blank=BLANK;
    if (cv_is_osiris(cv_fh)) {
      cv_cube=transpose(cv_cube, 0);
      if (!pixel){
        CRPIX1 = fits_get(cv_fh,"CRPIX2");
        CRVAL1 = fits_get(cv_fh,"CRVAL2");
        CDELT1 = fits_get(cv_fh,"CDELT2");
        CRPIX2 = fits_get(cv_fh,"CRPIX3");
        CRVAL2 = fits_get(cv_fh,"CRVAL3");
        CDELT2 = fits_get(cv_fh,"CDELT3");
      }
      CRPIX3 = fits_get(cv_fh,"CRPIX1");
      CRVAL3 = fits_get(cv_fh,"CRVAL1");
      CDELT3 = fits_get(cv_fh,"CDELT1");
      CUNIT3 = fits_get(cv_fh,"CUNIT1");
      CTYPE3 = "WAVE";
      if ( CUNIT3 == "nm" ) {
        CRVAL3 *= 0.001;
        CDELT3 *= 0.001;
      }
    } else {
      if (!pixel){
        CRPIX1 = fits_get(cv_fh,"CRPIX1");
        CRVAL1 = fits_get(cv_fh,"CRVAL1");
        CDELT1 = fits_get(cv_fh,"CDELT1");
        CRPIX2 = fits_get(cv_fh,"CRPIX2");
        CRVAL2 = fits_get(cv_fh,"CRVAL2");
        CDELT2 = fits_get(cv_fh,"CDELT2");
      }
      CRPIX3 = fits_get(cv_fh,"CRPIX3");
      CRVAL3 = fits_get(cv_fh,"CRVAL3");
      CDELT3 = fits_get(cv_fh,"CDELT3");
      CTYPE3 = fits_get(cv_fh,"CTYPE3");
    }
    if (is_numerical(CDELT1) && is_numerical(CRVAL1) && is_numerical(CRPIX1)) {
      cv_interns.scale(1)=CDELT1;
      cv_interns.origin(1)=CRVAL1-(CRPIX1-1)*CDELT1;
    }
    if (is_numerical(CDELT2) && is_numerical(CRVAL2) && is_numerical(CRPIX2)) {
      cv_interns.scale(2)=CDELT2;
      cv_interns.origin(2)=CRVAL2-(CRPIX2-1)*CDELT2;
    }
    if (is_numerical(CDELT3) && is_numerical(CRVAL3) && is_numerical(CRPIX3)) {
        cv_interns.scale(3)=CDELT3;
        cv_interns.origin(3)=CRVAL3-(CRPIX3-1)*CDELT3;
    } else if (is_bear(cv_fh)) {
        faxis=bear_faxis(cv_fh);
        cv_interns.zwlwise=0;
    }
    if ( CTYPE3 == "WAVE") cv_interns.zwlwise=1;
    else cv_interns.zwlwise=0;
  } else {
    cv_cube=double(data);
    cv_fh=[];
  }
  // Keywords overwritting defaults
  if (!is_void(blank)) cv_interns.blank=blank;
  if (!is_void(slice_wid)) cv_interns.slice_wid=slice_wid;
  if (!is_void(sp_wid))    cv_interns.sp_wid   =sp_wid   ;
  if (!is_void(cmd_wid))   cv_interns.cmd_wid  =cmd_wid  ;
  if (!is_void(depth))     cv_interns.depth    =depth    ;
  if (!is_void(origin))    cv_interns.origin   =origin   ;
  if (!is_void(scale))     cv_interns.scale    =scale    ;
  if (!is_void(overs))     cv_interns.overs    =overs    ;
  if (!is_void(slboxcol))  cv_interns.slboxcol =slboxcol ;
  if (!is_void(sltype))    cv_interns.sltype   =sltype   ;
  if (!is_void(slpalette)) cv_interns.slpalette=slpalette  ;
  __cv_palette=closure(palette, cv_interns.slpalette);
  if (!is_void(slinterp))  cv_interns.slinterp =slinterp  ;
  if (!is_void(zaxistype)) cv_interns.zaxistype=zaxistype;
  if (!is_void(refwl))     cv_interns.refwl    =refwl;
  if (!is_void(vlsr))      cv_interns.vlsr     =vlsr;
  if (!is_void(hook))      cv_interns.hook     =hook;
  if (!is_void(spkeywords)) cv_interns.spkeywords     =spkeywords;
  if (!is_void(zwlwise))   cv_interns.zwlwise  =zwlwise;
  //cv_interns.=override(cv_interns.,);
  // Try so set up the spectral axes
  data_dims=dimsof(cv_cube);
  if (data_dims(1) < 3) "This is no cube";
  cv_interns.zaxis=&indgen(data_dims(4));
  if (is_void(faxis) && is_void(waxis) && is_void(vaxis)){
      if (cv_interns.zwlwise) waxis=(*cv_interns.zaxis-1)*cv_interns.scale(3)+cv_interns.origin(3);
      else faxis=(*cv_interns.zaxis-1)*cv_interns.scale(3)+cv_interns.origin(3);
  }
  if (!is_void(faxis)) {
      cv_interns.faxis=&faxis ; // cm-1
      cv_interns.waxis=&(10000./faxis) ; // microns
      cv_interns.vaxis=&(voflambda(*cv_interns.waxis,cv_interns.refwl)/1000.); // km/s
  } else if (!is_void(waxis)) {
      cv_interns.waxis=&waxis ; // microns
      cv_interns.faxis=&(10000./waxis) ; // cm-1
      cv_interns.vaxis=&(voflambda(*cv_interns.waxis,cv_interns.refwl)/1000.); // km/s
  } else if (!is_void(vaxis)) {
      cv_interns.vaxis=&vaxis; // km/s
      cv_interns.waxis=&(lambdaofv(*cv_interns.vaxis*1000.,cv_interns.refwl)) ; // microns
      cv_interns.faxis=&(10000./(*cv_interns.waxis)) ; // cm-1
  }
  *cv_interns.vaxis=*cv_interns.vaxis+cv_interns.vlsr;
  if ((*cv_interns.waxis)(0)>(*cv_interns.waxis)(1)) cv_interns.zwlwise=1; else cv_interns.zwlwise=0;
  if (!is_void(zwlwise))  cv_interns.zwlwise =zwlwise ;
  cv_interns.sllims=[1,data_dims(4)];
  cv_interns.slpos=[cv_xpix2data(0.5),cv_ypix2data(0.5),cv_xpix2data(data_dims(2)+0.5),cv_ypix2data(data_dims(3)+0.5)];
  if (cv_interns.xyaspect==0.) cv_interns.xyaspect=double(data_dims(2))/data_dims(3);
  if (!is_void(isbig)) {
      cv_interns.isbig=isbig;
  } else {
    if (data_dims(2)*data_dims(3)*data_dims(4)>cv_defaults.big_size) {
      cv_interns.isbig=1;
      isbig=1;
    } else isbig=0;
  }
  if (!isbig){
      cv_valids=long(ieee_test(cv_cube)==0);
      if (ieee_test(cv_interns.blank)==0)
          cv_valids &= long(cv_cube != cv_interns.blank);
      indices=where(!cv_valids);
      if (numberof(indices)) cv_cube(indices)=0.;
  }
  if (!isbig) cv_slextract,1,data_dims(4);
  else cv_slextract,data_dims(4)/2,data_dims(4)/2;
  slice=*cv_interns.slice;
  
  cv_interns.cmin=min(slice);
  cv_interns.cmax=max(slice);
  if (!isbig) {
      if (cv_interns.aperture_type=="circular")
        cv_spextract,[data_dims(2),data_dims(3),data_dims(min:2:3)]/2;
      else cv_spextract,[1,1,data_dims(2),data_dims(3)];
  } else {
      if (cv_interns.aperture_type=="circular")
        cv_spextract,[data_dims(2)/2,data_dims(3)/2,1];
      else cv_spextract,[data_dims(2),data_dims(3),data_dims(2),data_dims(3)]/2;
  }
  if (!is_void(postinit)) include,postinit,1;
}

extern cv_xypix2data,cv_xydata2pix,cv_xpix2data,cv_xdata2pix,cv_ypix2data,cv_ydata2pix,cv_zpix2data,cv_zdata2pix;
/*DOCUMENT
  cv_xypix2data,cv_xydata2pix,cv_xpix2data,cv_xdata2pix,cv_ypix2data,cv_ydata2pix,cv_zpix2data,cv_zdata2pix

  Simple functions to go between data  pixels and the coordinate system used to
  plot. Currently  useless since  this system is  pixels (!), but  these should
  ease implementation of  world coordinates in the futures.  Some (but not all)
  of cubeview's routines are world coordinates-ready.
*/

func cv_xypix2data(xypix)
{
  extern cv_interns;
  resultat=cv_interns.origin(1:2)+(xypix-1)*cv_interns.scale(1:2);
  return resultat;
}

func cv_xydata2pix(xydata)
{
  extern cv_interns;
  return ([1.,1.]+(xydata-cv_interns.origin(1:2)/cv_interns.scale(1:2)));
}

func cv_xpix2data(xpix)
{
  extern cv_interns;
  return cv_interns.origin(1)+(xpix-1)*cv_interns.scale(1);
}

func cv_xdata2pix(xdata)
{
  extern cv_interns;
  return 1+(xdata-cv_interns.origin(1))/cv_interns.scale(1);
}

func cv_ypix2data(ypix)
{
  extern cv_interns;
  return cv_interns.origin(2)+(ypix-1)*cv_interns.scale(2);
}

func cv_ydata2pix(ydata)
{
  extern cv_interns;
  return 1+(ydata-cv_interns.origin(2))/cv_interns.scale(2);
}

func cv_current_zaxis(dummy)
/* DOCUMENT cv_current_zaxis()

     Returns  as  a vector  the  spectral  axis  currently used  by  Cubeview,
     considering the current state of cv_interns.zaxistype.
*/
{
    zaxistype=cv_interns.zaxistype;
    if (zaxistype=="PIX") return cv_interns.zaxis;
    else if (zaxistype=="FREQ") return cv_interns.faxis;
    else if (zaxistype=="WAVE") return cv_interns.waxis;
    else return cv_interns.vaxis;
}

func cv_zpix2data(zpix)
{
  extern cv_interns;
  //  return cv_interns.origin(3)+(zpix-1)*cv_interns.scale(3);
  //pix=cv_lround(zpix);
  axis=*cv_current_zaxis();
  if (zpix<1)  val=axis(1)-0.5*(axis(2)-axis(1));
  else if (zpix>dimsof(cv_cube)(4)) val=axis(0)+0.5*(axis(0)-axis(-1));
  else val=interp(axis,*cv_interns.zaxis,zpix)(1);
  return val;
  //  return (*cv_current_zaxis())(min(max(cv_lround(zpix),0),cv_interns.data_dims(4)));
}

func cv_zdata2pix(zdata)
{
  extern cv_interns;
  // return 1+(zdata-cv_interns.origin(3))/cv_interns.scale(3);
  return (abs(*cv_current_zaxis()-zdata))(mnx);
}

func cv_sldraw(depth=)
/* DOCUMENT cv_sldraw

     Displays current Cubeview slice (CV_SLICE) in the right window (pointed at
     by CV_SLICE_WID).  Displays a box around the spectrum region.
*/
{
  extern cv_nodraw;
  if (cv_nodraw) return;
  extern cv_interns;
  cv_slwin;
  fma;
  slice=*cv_interns.slice;
  slpos=cv_interns.slpos;
  if (cv_interns.sltype=="3 color") {
    if (is_void(depth)) depth=cv_interns.depth;
    im24=bytscl(cv_oversamp(slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
    if (depth==8) {
      im=cv_rgb2indexed(im24,red,green,blue);
      palette,red,green,blue;
      pli,im,slpos(1),slpos(2),slpos(3),slpos(4);
    } else {
      im=im24;
      cv_plfi,im,slpos(1),slpos(2),slpos(3),slpos(4);
      // eps output of RGB images traced using pli doesn't work. cv_plfi is a workaround.
    }
  } else if (cv_interns.sltype=="Normal") {
      pli,cv_oversamp(slice),slpos(1),slpos(2),slpos(3),slpos(4),
          cmin=cv_interns.cmin,cmax=cv_interns.cmax;
  }
  cv_putspbox;
  cv_callhook,"cv_sldraw";
}

func cv_slpnm(filename)
/* DOCUMENT cv_slpnm

     Write current slice,  affected by current cuts and  palette (for a "Normal
     slice"), to  an RGB PNM file (PPM),  using PNM_WRITE. The box  is saved in
     "axes_"+filename+".epsi", so that you can get the original image with axes
     using  xfig   for  instance,  so  LaTeX  programming   would  probably  be
     better. For  this kind of purpose,  I recommend using any  tool to convert
     the slice to JPEG, then jpeg2ps.  That allows to keep JPEG compression for
     the bitmap part.
*/
{
  extern cv_interns;
  require,"pnm.i";
  cv_slwin;
  if (cv_interns.sltype=="3 color") im=bytscl(*cv_interns.slice,cmin=cv_interns.cmin,cmax=cv_interns.cmax);
  else if (cv_interns.sltype=="Normal") im=pnm_colorize(*cv_interns.slice,cmin=cv_interns.cmin,cmax=cv_interns.cmax);
  pnm_write,im,filename;
  fma;
  plg,0,0;
  cv_sllims;
  eps,"axes_"+filename;
}

func cv_3colslice
/* DOCUMENT cv_3colslice & Cubeview's "3 color slice" radio button

     If you click on this button or  call this routine, all slices from then on
     will be of type "3 color".

     See cv_normalslice & Cubeview's "Normal slice" radio button.
*/
{
  extern cv_interns;
  cv_interns.sltype="3 color";
  cv_slextract;
  cv_cutregonce,1,1,0,0;
  cv_spdraw;
}

func cv_normalslice
/* DOCUMENT cv_normal slice & Cubeview's "Normal slice" radio button

     If you click on this button or  call this routine, all slices from then on
     will be of type "Normal", that is standard Yorick indexed color image.

     See cv_3colslice & Cubeview's "3 color slice" radio button.
*/
{
  extern cv_interns;
  cv_interns.sltype="Normal";
  cv_slextract;
  cv_slwin;
  __cv_palette;
  //palette,cv_interns.slpalette;
  cv_cutregonce,1,1,0,0;
  cv_spwin;
  //palette,cv_interns.slpalette;
  cv_spdraw;
  if (cv_ui=="gtk") noop, _cvgy.builder.get_object("Normal").set_active(1);
}

func cv_slextract_set_handler(wdg, evt, udata)
{
  gy_gtk_ywindow_mouse_handler,cv_interns.sp_wid, cv_slextract_handler;
}

func cv_slextract_handler(yid, x0, y0, x1, y1, button, flags)
{
  cv_slextract,cv_lround(cv_zdata2pix(x0)),cv_lround(cv_zdata2pix(x1));
  cv_sldraw;
  cv_spdraw;
}

func cv_spextract_handler(yid, x0, y0, x1, y1, button, flags)
{

  slice_wid=cv_interns.slice_wid;
  aperture_type=cv_interns.aperture_type;
  if (aperture_type=="rectangular") ty=1; else ty=2;
  window,slice_wid;
  if (aperture_type=="circular") {
    pp=[cv_xdata2pix(x0),cv_ydata2pix(y0),cv_xdata2pix(x1),cv_ydata2pix(y1)];
    if (button >=2 ) radius=max(sqrt(double(pp(3)-pp(1))^2+double(pp(4)-pp(2))^2),0.7);
    else radius=cv_interns.spbox(3);
    center=cv_lround(2*pp(1:2))/2.;
    cv_spextract,[center(1),center(2),radius];
  } else {
    pp=cv_lround([cv_xdata2pix(x0),cv_ydata2pix(y0),cv_xdata2pix(x1),cv_ydata2pix(y1)]);
    if (aperture_type=="rectangular") cv_spextract,[cv_xdata2pix(x0),cv_ydata2pix(y0),cv_xdata2pix(x1),cv_ydata2pix(y1)];
    else if (aperture_type=="square") {
      center=pp(1:2);
      if (button >=2 ) radius=max(abs([pp(3)-pp(1),pp(4)-pp(2)]));
      else radius=cv_interns.spbox(3);
      cv_spextract,[center(1),center(2),radius];
    }
  }
  cv_spdraw;
  cv_sldraw;
}

func cv_slcontrast_handler(yid, x0, y0, x1, y1, button, flags)
{
  extern cv_interns,__cv_cutbox;
  
  x0=cv_lround(cv_xdata2pix(x0));
  y0=cv_lround(cv_ydata2pix(y0));
  x1=cv_lround(cv_xdata2pix(x1));
  y1=cv_lround(cv_ydata2pix(y1));
  if (button==1) {
    cv_cutregonce, x0, y0, x1, y1;
  } else {
    if (cv_interns.sltype=="Normal") {
      cv_interns.cmin=(*cv_interns.slice)(x0,y0);
      cv_interns.cmax=(*cv_interns.slice)(x1,y1);
    } else if (cv_interns.sltype=="3 color") {
      cv_interns.cmin=sum((*cv_interns.slice)(,x0,y0));
      cv_interns.cmax=sum((*cv_interns.slice)(,x1,y1));      
    }
    __cv_cutbox=[x0,y0,x1,y1];
    cv_callhook,"cv_cutsel";
    cv_sldraw;
  }
}

func cv_spwin_handler(wdg, udata)
{
  if (wdg.get_active()) gy_gtk_ywindow_mouse_handler,cv_interns.sp_wid, [];
  else gy_gtk_ywindow_mouse_handler, cv_interns.sp_wid, cv_slextract_handler;
}

func cv_sltype_handler(wdg, udata)
{
  if (wdg.get_active()) cv_normalslice;
  else cv_3colslice;
}

func cv_slwin_handler(wdg, udata)
{
  if (!wdg.get_active()) return;
  id = gy.Gtk.Buildable(wdg).get_name();
  if      (id == "slzoom")     handler = [];
  else if (id == "spsel")      handler = cv_spextract_handler;
  else if (id == "slcontrast") handler = cv_slcontrast_handler;
  gy_gtk_ywindow_mouse_handler, cv_interns.slice_wid, handler;
}

func cv_slextract(begin,end)
/* DOCUMENT cv_slextract,begin,end
   
     Extracts new Cubview slice (*CV_INTERNS.SLICE) by summing up
     CV_CUBE planes from range BEGIN to range END. If called as a
     subroutine, updates a few items in CV_INTERNS. As a function,
     returns the slice.

     If cv_interns.sltype=="3 color", the slice is a 3xNxM array, all
     3 planes being sums of CV_CUBE planes from BEGIN to END with
     different ponderations.  This keeps some velocity information in
     the image displayed... (blueshifted regions can appear in blue
     and so...)
*/
{
  data_dims=dimsof(cv_cube);
  if (is_void(begin)) begin=cv_interns.sllims(1);
  if (is_void(end)) end=cv_interns.sllims(2);
  if (structof(begin)==double) "toto";
  if (structof(end)==double) "toto";
  b=min(begin,end);
  e=max(begin,end);
  b=max(b,1);
  e=min(e,data_dims(4));
  if (cv_interns.sltype=="Normal") {
      if (cv_interns.isbig) {
          valids=array(long,data_dims(2),data_dims(3));
          somme=array(structof(cv_cube(1,1,1)),data_dims(2),data_dims(3));
          for (z=b;z<=e;z++) {
              valid=cv_valids(,,z);
              if (anyof(valid)) {
                  ind=where(valid);
                  somme(ind)+=(cv_cube(,,z))(ind);
                  valids(ind)+=valid(ind);
              }
          }
      } else {
          somme=cv_cube(,,sum:b:e);
          valids=cv_valids(,,sum:b:e);
      }
      indices=where(valids==0);
      if (numberof(indices)) valids()=1; // if noneof(valids), somme==0 anyway.
      slice=somme/valids;
  } else {
     slice=array(double,3,data_dims(2),data_dims(3));
     filters=cv_rgbfilters(e-b+1);
     for (i=b;i<=e;i++) {
        valids=cv_valids(,,i);
        plane=cv_cube(,,i);
        w = where(!valids);
        if (numberof(w)) plane(w)=0.;
        for (c=1;c<4;c++) slice(c,,)=slice(c,,)+filters(c,i-b+1)*plane;
    }
  }
  slice=cv_gauss_smooth(slice,cv_interns.slsmooth);
  if (am_subroutine()) {
    cv_interns.sllims=[b,e];
    cv_interns.slice=&slice;
  }
  else return slice;
}

func cv_spsel
/* DOCUMENT  cv_spsel, Cubeview's "Select spectrum button".

   Choose rectangle on Window 0  with left mouse button, extracts corresponding
   spectrum  *CV_INTERNS.SPECTRUM  from CV_CUBE,  draws  it to  window
   CV_INTERNS.SP_WID.

   CV_SPSEL loops  until you hit any other window.
*/
{
  extern cv_interns;
  slice_wid=cv_interns.slice_wid;
  aperture_type=cv_interns.aperture_type;
  if (aperture_type=="rectangular") ty=1; else ty=2;
  window,slice_wid;
  p=cv_mouse(1,ty,"");
  while (p(10) >= 1) {
      if (aperture_type=="circular") {
          pp=[cv_xdata2pix(p(1)),cv_ydata2pix(p(2)),cv_xdata2pix(p(3)),cv_ydata2pix(p(4))];
          if (p(10) >=2 ) radius=max(sqrt(double(pp(3)-pp(1))^2+double(pp(4)-pp(2))^2),0.7);
          else radius=cv_interns.spbox(3);
          center=cv_lround(2*pp(1:2))/2.;
          cv_spextract,[center(1),center(2),radius];
      } else {
          pp=cv_lround([cv_xdata2pix(p(1)),cv_ydata2pix(p(2)),cv_xdata2pix(p(3)),cv_ydata2pix(p(4))]);
          if (aperture_type=="rectangular") cv_spextract,[cv_xdata2pix(p(1)),cv_ydata2pix(p(2)),cv_xdata2pix(p(3)),cv_ydata2pix(p(4))];
          else if (aperture_type=="square") {
              center=pp(1:2);
              if (p(10) >=2 ) radius=max(abs([pp(3)-pp(1),pp(4)-pp(2)]));
              else radius=cv_interns.spbox(3);
              cv_spextract,[center(1),center(2),radius];
          }
      }
//    p;
//    [cv_xdata2pix(p(1)),cv_ydata2pix(p(2)),cv_xdata2pix(p(3)),cv_ydata2pix(p(4))];
      //    cv_spextract,p(1:4);
      cv_spdraw;
      cv_sldraw;
      window,slice_wid;
      p=cv_mouse(1,ty,"");
  }
}

func cv_spdraw(pos)
/* DOCUMENT cv_spdraw

     Displays  current Cubeview  spectrum (*CV_INTERNS.SPECTRUM)  in  the right
     window (pointed  at by  CV_INTERNS.SP_WID).  Displays the  spectral region
     defining the slice on a colored background.
*/
{
  if (cv_nodraw) return;
  extern cv_interns;
  cv_spwin;
  fma;
  cv_putslbox;
  plhk,(*cv_interns.spectrum),(*cv_current_zaxis()),keywords=cv_interns.spkeywords;
  cv_callhook,"cv_spdraw";
  redraw;
}

func cv_putslbox(depth=)
/* DOCUMENT cv_putslbox

   Displays a colored box representing the spectral region corresponding to the
   slice in Cubeview's spectral window.
*/
{
  extern cv_interns;
  cv_spwin;
  t1=min(cv_interns.sllims(1:2));
  t2=max(cv_interns.sllims(1:2));
  low=cv_zpix2data(t1-0.5);
  high=cv_zpix2data(t2+0.5);
  //  t1=cv_zpix2data(cv_interns.sllims(1)-0.5);
  //  t2=cv_zpix2data(cv_interns.sllims(2)+0.5);
  //  low=min(t1,t2);
  //  high=max(t1,t2);
  mi=min(*cv_interns.spectrum);
  ma=max(*cv_interns.spectrum);
  mami=ma-mi;
  mi=mi-0.02*mami;
  ma=ma+0.02*mami;
  col=cv_interns.slboxcol;
  if (cv_interns.sltype=="Normal") plf,[[col,col],[col,col]],[[mi,ma],[mi,ma]],[[low,low],[high,high]];
  else if (cv_interns.sltype=="3 color") {
    s=cv_interns.sllims(2)-cv_interns.sllims(1)+1;
    ima24=array(char,3,s,1);
    ima24(,,1)=char(bytscl(cv_rgbfilters(s),top=100))+char(155);
    if (is_void(depth)) depth=cv_interns.depth;
    if (depth==8){
      ima=cv_rgb2indexed(ima24,red,green,blue);
      fma;
      palette,red,green,blue;
      pli,ima,low,mi,high,ma;
    } else {
      ima=ima24;
      cv_plfi,ima,low,mi,high,ma;
    }
    //    c=s/2.;
    // for (i=1;i<=floor(c);i++) ima(1,i,)=1-(i/c)^2;
    // for (i=long(ceil(c));i<=s;i++) ima(3,i,)=1-((s-i)/c)^2;
    // ima(2,,)=1-ima(1,,)-ima(3,,);
    // pli,bytscl(ima,top=100)+char(155),low,mi,high,ma;
  }
}

func cv_lround(x)
/* DOCUMENT long=cv_lround(float)
  // from mathbast.i
  Acts as expected : return long(x+0.5*((x>0)*2-1));
*/
{
  return long(x+0.5*((x>0)*2-1));
}

func cv_spextract(pos, cube)
/* DOCUMENT cv_spextract,corners

     Extracts  new  Cubeview  spectrum  (*CV_INTERNS.SPECTRUM)  by  summing  up
     *CV_INTERNS.DATA   spectra  included  in   rectangular  area   difined  by
     CORNERS=[X0,Y0,X1,Y1]. Updates CV_INTERNS accordingly.
*/
{
  extern cv_interns;
  if (is_void(cube)) cube=&cv_cube;
  data_dims=dimsof(*cube);
  isbig=cv_interns.isbig;
  if (is_void(pos)) pos=cv_interns.spbox;
  if (cv_interns.aperture_type=="circular") {
      x0=pos(1);
      y0=pos(2);
      radius=pos(3);
      cv_interns.spbox=[x0,y0,radius,0];
      llx=max(1,long(floor(x0-radius)));
      lly=max(1,long(floor(y0-radius)));
      urx=min(data_dims(2),long(ceil(x0+radius)));
      ury=min(data_dims(3),long(ceil(y0+radius)));
      mask=cv_circmas(urx-llx+1,ury-lly+1,x0-llx+1,y0-lly+1,radius);
      if (isbig) {
          somme=(*cube)(1,1,);
          nz=data_dims(4);
          valids=array(long,nz);
          for (z=1l;z<=nz;z++){
              vals=cv_valids(llx:urx,lly:ury,z)*mask;
              valids(z)=sum(vals);
              if (valids(z)>0) {
                  ind=where(vals);
                  somme(z)=sum(((*cube)(llx:urx,lly:ury,z))(ind));
              } else {
                  somme(z)=0.;
              }
          }
      } else {
          somme=((*cube)(llx:urx,lly:ury,)*mask(,,-))(sum,sum,);
          valids=(cv_valids(llx:urx,lly:ury,)*mask(,,-))(sum,sum,);
      }
  } else {
      if (cv_interns.aperture_type=="rectangular") {
          llx=max(1,min(cv_lround(pos([1,3]))));
          lly=max(1,min(cv_lround(pos([2,4]))));
          urx=min(data_dims(2),cv_lround(max(pos([1,3]))));
          ury=min(data_dims(3),cv_lround(max(pos([2,4]))));
          cv_interns.spbox=[llx,lly,urx,ury];
      } else {
          // square
          x0=cv_lround(pos(1));
          y0=cv_lround(pos(2));
          radius=cv_lround(pos(3));
          cv_interns.spbox=[x0,y0,radius,0];
          llx=max(1,x0-radius);
          lly=max(1,y0-radius);
          urx=min(data_dims(2),cv_lround(x0+radius));
          ury=min(data_dims(3),cv_lround(y0+radius));
      }
      if (isbig) {
          // here "valids" is sum(cv_valids(...))
          somme=(*cube)(1,1,);
          nz=data_dims(4);
          valids=array(long,nz);
          for (z=1l;z<=nz;z++){
              vals=cv_valids(llx:urx,lly:ury,z);
              valids(z)=sum(vals);
              if (valids(z)>0) {
                  ind=where(vals);
                  somme(z)=sum((*cube)(llx:urx,lly:ury,z)(ind));
              } else {
                  somme(z)=0.;
              }
          }
      } else {
          somme=(*cube)(sum:llx:urx,sum:lly:ury,);
          valids=cv_valids(sum:llx:urx,sum:lly:ury,);
      }
  }
  // for non-valids, somme is 0. put valids to 1 to avoid dividing by 0.
  indices=where(valids==0);
  if (numberof(indices)) valids(indices)=1;
  spectrum=cv_gauss_smooth(somme/valids,cv_interns.spsmooth);
  if (cube == &cv_cube) {
    cv_interns.spectrum=&spectrum;
    // note: the above is ugly when we have non-valids (set to 0).
    cv_callhook,"cv_spextract";
  }
  return spectrum;
}

func cv_putspbox(win=)
/* DOCUMENT cv_putspbox

     Puts a box arround the  region defining the current spectrum in cubeview's
     slice window.
*/
{
  extern cv_interns;
  spbox=cv_interns.spbox;
  aperture_type=cv_interns.aperture_type;
  data_dims=dimsof(cv_cube);
  if (is_void(win)) cv_slwin; else window,win;
  if (aperture_type=="rectangular") {
      llx=cv_xpix2data(spbox(1)-0.5);
      lly=cv_ypix2data(spbox(2)-0.5);
      urx=cv_xpix2data(spbox(3)+0.5);
      ury=cv_ypix2data(spbox(4)+0.5);
      plg,[lly,ury,ury,lly,lly],[llx,llx,urx,urx,llx],color="white",width=6;
      plg,[lly,ury,ury,lly,lly],[llx,llx,urx,urx,llx];
  } else {
      x0=spbox(1);
      y0=spbox(2);
      radius=spbox(3);
      if (aperture_type=="square") {
          llx=cv_xpix2data(x0-radius-0.5);
          lly=cv_xpix2data(y0-radius-0.5);
          urx=cv_xpix2data(x0+radius+0.5);
          ury=cv_xpix2data(y0+radius+0.5);
          plg,[lly,ury,ury,lly,lly],[llx,llx,urx,urx,llx],color="white",width=6;
          plg,[lly,ury,ury,lly,lly],[llx,llx,urx,urx,llx];
      } else {
// needs to find how to properly draw the "circle"
          mask=cv_circmas(data_dims(2)+1,data_dims(3)+1,x0+1,y0+1,radius);
          slpos=cv_interns.slpos;
          xx=array(span(slpos(1),slpos(3),data_dims(2)+1),data_dims(3)+1);
          yy=transpose(array(span(slpos(2),slpos(4),data_dims(3)+1),data_dims(2)+1));
          plm,yy,xx,mask,boundary=1,color="white",width=6;
          plm,yy,xx,mask,boundary=1;
      }
  }
}

func cv_slsel
/* DOCUMENT  cv_slsel, Cubeview's "Select slice" button

   Choose rectangle on Window 0  with left mouse button, extracts corresponding
   splice   CV_INTERNS.SLICE   from  CV_INTERNS.DATA,   draws   it  to   window
   CV_INTERNS.SLICE_WID.

   CV_SLSEL loops  until you hit  any other button  than the left in  the slice
   window, or any button in any other window.
*/
{
  extern cv_interns;
  cv_spwin;
      if (catch(-1)) {
        resume;
        return;
      }
  p=cv_mouse(1,1,"");
  while (p(10) == 1) {
    cv_slextract,cv_lround(cv_zdata2pix(p(1))),cv_lround(cv_zdata2pix(p(3)));
    cv_sldraw;
    cv_spdraw;
    cv_spwin;
      if (catch(-1)) {
        resume;
        return;
      }
    p=cv_mouse(1,1,"");
  }
}

func cv_slwin
/* DOCUMENT cv_slwin
   Switches to windows CV_INTERNS.SLICE_WID
*/
{
  extern cv_interns, cv_nodraw;
  if (cv_nodraw) return;
  window,cv_interns.slice_wid;
}

func cv_spwin
/* DOCUMENT cv_slwin Switches to windows CV_INTERNS.SP_WID
*/
{
  extern cv_interns, cv_nodraw;
  if (cv_nodraw) return;
  window,cv_interns.sp_wid;
}

func cv_cutsel
/* DOCUMENT cv_cutsel

     On  Cubeview's  slice window  (CV_INTERNS.SLICE_WID),  click from  minimum
     pixel to maximum pixel to draw.

   SEE ALSO: cv_cutreg, cv_library
*/
{
  extern cv_interns,__cv_cutbox;
  cv_slwin;
  resume;
  p=(cv_mouse(1,2,""));
  while (p(10) == 1) {
    x0=cv_lround(cv_xdata2pix(p(1)));
    y0=cv_lround(cv_ydata2pix(p(2)));
    x1=cv_lround(cv_xdata2pix(p(3)));
    y1=cv_lround(cv_ydata2pix(p(4)));    
    if (cv_interns.sltype=="Normal") {
      cv_interns.cmin=(*cv_interns.slice)(x0,y0);
      cv_interns.cmax=(*cv_interns.slice)(x1,y1);
    } else if (cv_interns.sltype=="3 color") {
      cv_interns.cmin=sum((*cv_interns.slice)(,x0,y0));
      cv_interns.cmax=sum((*cv_interns.slice)(,x1,y1));      
    }
    __cv_cutbox=[x0,y0,x1,y1];
    cv_callhook,"cv_cutsel";
    cv_sldraw;
    cv_slwin;
    resume;
    p=(cv_mouse(1,2,""));
  }
}

func cv_cutregonce(x0,y0,x1,y1)
/* DOCUMENT cv_cutregonce
         or cv_cutregonce,x0,y0,x1,y1

    Adjust  contrast on  the  output image  by  setting its  min/max value  to
    min/max  of  selected square  region,  specified  by  corners (x0,y0)  and
    (x1,y1).  If not specified,  the entire  image is  used. Then  redraws the
    slice.

   SEE ALSO: cv_cutreg, cv_library
*/
{
  extern cv_interns,__cv_cutbox;
  data_dims=dimsof(cv_cube);
  if (is_void(x0)) {
    x0=y0=1;
    x1=y1=0;
  }
  if (x0<=0) x0=x0+data_dims(2);
  if (y0<=0) y0=y0+data_dims(3);
  if (x1<=0) x1=x1+data_dims(2);
  if (y1<=0) y1=y1+data_dims(3);
  llx=max(min(x0,x1),1);
  lly=max(min(y0,y1),1);
  urx=min(max(x0,x1),data_dims(2));
  ury=min(max(y0,y1),data_dims(3));
  __cv_cutbox=[llx,lly,urx,ury];
  if (cv_interns.sltype=="Normal") portion=(*cv_interns.slice)(llx:urx,lly:ury);
  else if (cv_interns.sltype="3 color") portion=(*cv_interns.slice)(max,llx:urx,lly:ury);
  cv_interns.cmin=min(portion);
  cv_interns.cmax=max(portion);
  cv_callhook,"cv_cutregonce";
  cv_sldraw;
}

func cv_callhook(caller){
      extern cv_interns;
      if (cv_interns.hook!=string()) call,symbol_def(cv_interns.hook)(caller);
}

func cv_cutreg
/* DOCUMENT cv_cutreg

     On Cubeview's  slice window (CV_INTERNS.SLICE_WID),  select with mouse rectangular area
     which contrast is to be maximized.

   SEE ALSO: cv_cutsel, cv_cutregonce, cv_library
*/
{
  extern cv_interns;
  cv_slwin;
  resume;
  p=(cv_mouse(1,1,""));
  while (p(10)==1) {
    x0=cv_lround(cv_xdata2pix(p(1)));
    y0=cv_lround(cv_ydata2pix(p(2)));
    x1=cv_lround(cv_xdata2pix(p(3)));
    y1=cv_lround(cv_ydata2pix(p(4)));
    cv_cutregonce,x0,y0,x1,y1;
    cv_slwin;
    resume;
    p=(cv_mouse(1,1,""));
  }
}

////////// Command window

func cv_cmd_win_init
/* DOCUMENT cv_cmd_win_init

     Initializes  Cubeview's  almost  graphical  user  interface.  Not  a  user
     function: is intended to be called by CUBEVIEW.

*/
{
  extern cv_interns;
  grid_keywords=GraphK(width=&long(6),marks=&long(0));
  lines=13;
  root=tws_root(wid=cv_interns.cmd_wid,uname="Cubeview",width=130,height=25*lines);
  grid0=tws_grid(parent=root,cols=1,lines=lines,frame_keywords=grid_keywords);
  grid=tws_grid(parent=grid0,cols=1,lines=2,frame_keywords=grid_keywords);
  //  tws_button,parent=grid,label="Redraw",uname="cv_graphicwindows";
  tws_button,parent=grid,label="Sel. spectrum",uname="cv_spsel";
  tws_button,parent=grid,label="Sel. slice",uname="cv_slsel";
  grid=tws_grid(parent=grid0,cols=1,lines=2,frame_keywords=grid_keywords);
  tws_button,parent=grid,label="Spect. zoom/pan",uname="sp-zoom-pan";
  tws_button,parent=grid,label="Slice zoom/pan",uname="sl-zoom-pan";
  //normsl=tws_radio(parent=grid,label="Normal slice",uname="cv_normalslice");
  //sl3=tws_radio(parent=grid,label="3 color slice",uname="cv_3colslice");
  grid=tws_grid(parent=grid0,cols=1,lines=2,frame_keywords=grid_keywords);
  tws_button,parent=grid,label="Slice properties",uname="slprop";
  tws_button,parent=grid,label="Spect. properties",uname="spprop";
  grid=tws_grid(parent=grid0,cols=1,lines=2,frame_keywords=grid_keywords);
  tws_button,parent=grid,label="Min/Max contrast",uname="cv_cutsel";
  tws_button,parent=grid,label="Region contrast",uname="cv_cutreg";
  grid=tws_grid(parent=grid0,cols=1,lines=3,frame_keywords=grid_keywords);
  tws_button,parent=grid,label="Spectrum limits",uname="splims";
  tws_button,parent=grid,label="Spectrum Y limits",uname="cv_freeylimits";
  tws_button,parent=grid,label="Slice limits",uname="cv_sllims";
  //tws_button,parent=grid,label="Slice -> eps",uname="cv_rgbeps";
  grid=tws_grid(parent=grid0,cols=1,lines=2,frame_keywords=grid_keywords);
  tws_button,parent=grid,label="Help",uname="cv_help";
  tws_button,parent=grid,label="Suspend",uname="cv_suspend";
  tws_realize,root;
  //if (cv_interns.sltype=="Normal") rien=tws_action(normsl)(normsl,action="Select");
  //else if (cv_interns.sltype=="3 color") rien=tws_action(sl3)(sl3,action="Select");
  cv_interns.root=root;
}

func cvgy_handler(wdg, evt, udt)
{
  "here";
}

func cv_handler(event)
/* DOCUMENT cv_handler(uname,button)

     Cubeview  event handler.  Not a  user  function, normally  called only  by
     TWS_HANDLER.   
*/
{
  button=event.button;
  uname=event.widget->uname;
  if (button == 1) {
    if  (uname=="cv_suspend") {
      cv_suspend;
      return 2;
    }
    else if (uname=="splims") {
      extern cv_nodraw;
      if (cv_nodraw) return;
      cv_spwin;
      limits;
    }
    else if (uname=="cv_freeylimits") {
      extern cv_nodraw;
      if (cv_nodraw) return;
      cv_freeylimits;
    }
    else if (uname=="slprop") {
      cv_popup_init;
      tws_handler,cv_interns.popup,"cv_popuphandler";
      cv_cmd_win_init;
    }
    else if (uname=="spprop") {
      cv_popup2_init;
      tws_handler,cv_interns.popup,"cv_popup2handler";
      cv_cmd_win_init;
    } else if (uname=="sl-zoom-pan") {
        cv_slwin;
        cv_zoom;
    } else if (uname=="sp-zoom-pan") {
        cv_spwin;
        cv_zoom;
    }
    else symbol_def(uname);
  }
  else {
    if (uname=="splims") write,"Click here to apply LIMITS to Cubeview's spectrum window";
    else if (uname=="slprop") help,cv_popuphandler;
    else if (uname=="sl-zoom-pan") {write,"Zoom/pan slice window:"; help,cv_zoom;}
    else if (uname=="sp-zoom-pan") {write,"Zoom/pan spectrum window:"; help,cv_zoom;}
    else help, symbol_def(uname);
  }
  return 0;
}

//////// First pop-up window: slice properties

extern cv_popup_init,cv_popuphandler;
/* DOCUMENT   cv_popup_init,cv_popuphandler & Cubeview's "Slice properties" button

     Clicking on the  button in Cubeview's command window  makes this window be
     replaced  by a  dialog box  allowing  to set  a few  parameters for  slice
     display:  oversampling factor, depth  of "3  color" slice  (8 or  24), and
     palette for "normal" slice.

     You  get out  of this  dialog box  by right  clicking in  it (there  is no
     context help there).
     
   SEE ALSO: cubeview, cv_interns, cv_defaults, cv_library
*/

func cv_popup_init
/* DOCUMENT cv_cmd_win_init

     Initializes  Cubeview's  almost  graphical  user  interface.  Not  a  user
     function: is intended to be called by CUBEVIEW.

*/
{
  extern cv_interns;
  lines=[2,2,2,2,9];
  root=tws_root(wid=cv_interns.cmd_wid,uname="Cubeview",width=130,height=25*sum(lines));
  //grid1=tws_grid(parent=root,lines=3);
  //grid=tws_grid(parent=grid1,cols=1,lines=lines(1));
  grid=tws_grid(parent=root,cols=1,lines=lines(1),position=[0,0,1,double(lines(1))/sum(lines)]);
  tws_field,parent=grid,label="",uname="overs",value=cv_interns.overs,frame=0,prompt="Oversampling factor: ";
  tws_label,parent=grid,label="Oversampling: ",uname="help";

  grid=tws_grid(parent=root,cols=1,lines=lines(2),position=[0,double(lines(1))/sum(lines),1,double(sum(lines(1:2)))/sum(lines)]);
  tws_field,parent=grid,label="",uname="slsmooth",value=cv_interns.slsmooth,frame=0,prompt="Slice smoothing FWHM: ";
  tws_label,parent=grid,label="Smoothing FWHM: ",uname="help";

  grid=tws_grid(parent=root,cols=1,lines=lines(3),position=[0,double(sum(lines(1:2)))/sum(lines),1,double(sum(lines(1:3)))/sum(lines)]);
  //grid=tws_grid(parent=grid1,cols=1,lines=lines(2));
  bit24=tws_radio(parent=grid,label="24bit RGB slice",uname="24bit");
  bit8=tws_radio(parent=grid,label="8bit RGB slice",uname="8bit");

  grid=tws_grid(parent=root,cols=1,lines=lines(4),position=[0,double(sum(lines(1:3)))/sum(lines),1,double(sum(lines(1:4)))/sum(lines)]);
  normsl=tws_radio(parent=grid,label="Normal slice",uname="cv_normalslice");
  sl3=tws_radio(parent=grid,label="3 color slice",uname="cv_3colslice");

  
  grid=tws_grid(parent=root,cols=1,lines=lines(5),position=[0,double(sum(lines(1:4)))/sum(lines),1,double(sum(lines(1:5)))/sum(lines)]);
  //grid=tws_grid(parent=grid1,cols=1,lines=lines(3));
  earth  =tws_radio(parent=grid,label="earth",uname="earth");
  gray   =tws_radio(parent=grid,label="gray",uname="gray");
  heat   =tws_radio(parent=grid,label="heat",uname="heat");
  ncar   =tws_radio(parent=grid,label="ncar",uname="ncar");
  rainbow=tws_radio(parent=grid,label="rainbow",uname="rainbow");
  stern  =tws_radio(parent=grid,label="stern",uname="stern");
  yarg   =tws_radio(parent=grid,label="yarg",uname="yarg");

//  grid=tws_grid(parent=root,cols=1,lines=lines(4),position=[0,double(sum(lines(1:3)))/sum(lines(1:4)),1,1]);
  tws_button,parent=grid,label="Help",uname="help";

  tws_realize,root;
  depth=cv_interns.depth;
  if (depth==8) rien=tws_action(bit8)(bit8,action="Select");
  else if (depth==24) rien=tws_action(bit24)(bit24,action="Select");

  if (cv_interns.sltype=="Normal") rien=tws_action(normsl)(normsl,action="Select");
  else if (cv_interns.sltype=="3 color") rien=tws_action(sl3)(sl3,action="Select");

  pal=cv_interns.slpalette;
  if (pal=="earth.gp") rien=tws_action(earth)(earth,action="Select");
  else if (pal=="gray.gp") rien=tws_action(earth)(gray   ,action="Select");
  else if (pal=="heat.gp") rien=tws_action(earth)(heat   ,action="Select");
  else if (pal=="ncar.gp") rien=tws_action(earth)(ncar   ,action="Select");
  else if (pal=="rainbow.gp") rien=tws_action(earth)(rainbow,action="Select");
  else if (pal=="stern.gp") rien=tws_action(earth)(stern  ,action="Select");
  else if (pal=="yarg.gp") rien=tws_action(earth)(yarg   ,action="Select");

  cv_interns.popup=root;
}

func cv_sltype(name)
{
  if (name=="Normal") cv_normalslice;
  else if (name=="3 color") cv_3colslice;
  else error,name+" is not a valid slice type";
    
}

func cv_depth(name, udata)
{
  if (!is_array(name)) {
    if (!name.get_active()) return;
    name = gy.Gtk.Buildable(name).get_name();
  }
  if (name=="8bit") cv_interns.depth=8;
  else if (name=="24bit") cv_interns.depth=24;
  else error,name+" is not a valid depth";
  cv_3colslice;
   
}

func cv_set_refwl(value, udata)
{
  if (!is_array(value)) {
    value = value.get_value();
  }
  cv_newrefwl,double(value);
  cv_spdraw;
}


func cv_set_overs(value, udata)
{
  if (!is_array(value)) value = value.get_value();
  if (value == 0.) value = 1.;
  cv_interns.overs=double(value);
  cv_sldraw;
}

func cv_set_slsmooth(value, udata)
{
  if (!is_array(value)) value = value.get_value();
  cv_interns.slsmooth=double(value);
  cv_slextract;
  cv_sldraw;
}

func cv_set_spsmooth(value, udata)
{
  if (!is_array(value)) value = value.get_value();
  cv_interns.spsmooth=double(value);
  cv_spextract;
  cv_spdraw;
}

func cv_set_palette(name,no_update)
{
  cv_interns.slpalette=name+".gp";
  if (!no_update) cv_normalslice;
}

func cv_gycmap_callback(cmd, map) {
  extern __cv_palette;
  __cv_palette=closure(cmd, map);
  if (!no_update) cv_normalslice;
}

func cv_gycmap(wdg, udata) {
  cv_slwin;
  gycmap, cv_gycmap_callback;
}

func cv_popuphandler(event)
/* DOCUMENT cv_popuphandler(uname,button)

     Cubeview event handler for a  popup.  Not a user function, normally called
     only by TWS_HANDLER.
*/
{
  button=event.button;
  uname=event.widget->uname;
  if (button==1) {
    if  (uname=="24bit") {
      cv_interns.depth=24;
      cv_3colslice;
    }
    else if (uname=="8bit") {
      cv_interns.depth=8;
      cv_3colslice;
    }
    else if (uname=="overs") {
      cv_interns.overs=event.value;
      cv_sldraw;
    }
    else if (uname=="help") {
      help,cv_popuphandler;
    }
    else if (sum(uname==["earth","gray","heat","ncar","rainbow","stern","yarg"])) {
     cv_interns.slpalette=uname+".gp";
     cv_normalslice;
    }
      else if (uname=="slsmooth") {
          cv_interns.slsmooth=event.value;
          cv_slextract;
          cv_sldraw;
      }
    else symbol_def(uname);
    return 0;
  } else return 2;
}

//////////// Second pop-up window: Spectrum properties

extern cv_popup2_init,cv_popup2handler;
/* DOCUMENT   cv_popup_init,cv_popuphandler & Cubeview's "Spect. properties" button

     Clicking on the button in  Cubeview's command window makes this window be
     replaced by  a dialog box allowing  to set a few  parameters for spectrum
     display: type of Z axis, reference wavelength.

     You  get out  of this  dialog box  by right  clicking in  it (there  is no
     context help there).
     
   SEE ALSO: cubeview, cv_interns, cv_defaults, cv_library
*/

func cv_popup2_init
/* DOCUMENT cv_cmd_win_init

     Initializes  Cubeview's  almost  graphical  user  interface.  Not  a  user
     function: is intended to be called by CUBEVIEW.

*/
{
  extern cv_interns;
  lines=[2,2,3,4];
  root=tws_root(wid=cv_interns.cmd_wid,uname="Cubeview",width=130,height=25*sum(lines));
  //grid1=tws_grid(parent=root,lines=3);
  //grid=tws_grid(parent=grid1,cols=1,lines=lines(1));
  grid=tws_grid(parent=root,cols=1,lines=lines(1),position=[0,0,1,double(lines(1))/sum(lines)]);
  tws_field,parent=grid,label="",uname="refwl",value=cv_interns.refwl,frame=0,prompt="Reference wavelength: ";
  tws_label,parent=grid,label="Ref. WL: ",uname="help";

  grid=tws_grid(parent=root,cols=2,lines=lines(2),position=[0,double(lines(1))/sum(lines),1,double(sum(lines(1:2)))/sum(lines)]);
  tws_field,parent=grid,label="",uname="spsmooth",value=cv_interns.spsmooth,frame=0,prompt="Spectrum smoothing FWHM: ";
  tws_label,parent=grid,label="Smoothing FWHM: ",uname="help";

  grid=tws_grid(parent=root,cols=1,lines=lines(3),position=[0,double(sum(lines(1:2)))/sum(lines),1,double(sum(lines(1:3)))/sum(lines)]);
  rectangular=tws_radio(parent=grid,label="Rect. aper.",uname="rectangular");
  square=tws_radio(parent=grid,label="Square aper.",uname="square");
  circular=tws_radio(parent=grid,label="Circ. aper.",uname="circular");

  grid=tws_grid(parent=root,cols=1,lines=lines(4),position=[0,double(sum(lines(1:3)))/sum(lines),1,double(sum(lines(1:4)))/sum(lines)]);
  //grid=tws_grid(parent=grid1,cols=1,lines=lines(2));
  PIX=tws_radio(parent=grid,label="Pixels",uname="PIX");
  FREQ=tws_radio(parent=grid,label="Freq. (cm-1)",uname="FREQ");
  WAVE=tws_radio(parent=grid,label="Wavelength (microns)",uname="WAVE");
  VEL=tws_radio(parent=grid,label="Velocity (km/s)",uname="VEL");

  
//  tws_button,parent=grid,label="Help",uname="help";
  tws_realize,root;
  zaxistype=cv_interns.zaxistype;
  rien=tws_action(symbol_def(zaxistype))(symbol_def(zaxistype),action="Select");
  aperture_type=cv_interns.aperture_type;
  rien=tws_action(symbol_def(aperture_type))(symbol_def(aperture_type),action="Select");
  cv_interns.popup=root;
}

func cv_set_sptype(uname, udata) {
  if (!is_string(uname)) {
    // called as Gtk handler
    if (!uname.get_active()) return;
    uname=gy.Gtk.Buildable(uname).get_name();
  }
  extern cv_nodraw;
  if (cv_nodraw) return;
  cv_spwin;
  old_limits=limits();
  lowpix=cv_zdata2pix(old_limits(1));
  highpix=cv_zdata2pix(old_limits(2));
  cv_interns.zaxistype=uname;
  old_limits(1)=cv_zpix2data(lowpix);
  old_limits(2)=cv_zpix2data(highpix);
  limits,old_limits;
  cv_spdraw;
}

func cv_set_aperture(uname, udata) {
  if (!is_string(uname)) {
    // called as Gtk handler
    if (!uname.get_active()) return;
    uname=gy.Gtk.Buildable(uname).get_name();
  }
  old_type=cv_interns.aperture_type;
  old_box=cv_interns.spbox;
  if (old_type==uname) return;
  if (old_type=="rectangular") {
    x0=(old_box(3)+old_box(1))/2;
    y0=(old_box(4)+old_box(2))/2;
    radius=min(old_box(3)-old_box(1),old_box(4)-old_box(2))/2;
  } else {
    x0=old_box(1);
    y0=old_box(2);
    radius=old_box(3);
  }
  if (uname=="rectangular") {
    llx=x0-radius;
    lly=y0-radius;
    urx=x0+radius;
    ury=y0+radius;
    spbox=[llx,lly,urx,ury];
  } else spbox=[x0,y0,radius];
  cv_interns.aperture_type=uname;
  cv_spextract,spbox;
  cv_spdraw;
  cv_sldraw;
}

func cv_popup2handler(event)
/* DOCUMENT cv_popuphandler(uname,button)

     Cubeview event handler for a  popup.  Not a user function, normally called
     only by TWS_HANDLER.
*/
{
  button=event.button;
  uname=event.widget->uname;
  if (button==1) {
      if  (sum(uname==["PIX","FREQ","WAVE","VEL"])) {
          cv_set_sptype(uname);
      }
      if  (sum(uname==["rectangular","square","circular"])) {
          cv_set_aperture(uname);
      }
      else if (uname=="refwl") {
          cv_newrefwl,event.value;
          cv_spdraw;
      }
      else if (uname=="spsmooth") {
          cv_interns.spsmooth=event.value;
          cv_spextract;
          cv_spdraw;
      }
      else if (uname=="help") {
          help,cv_popuphandler;
      }
      return 0;
  } else return 2;
}

func cv_help
/* DOCUMENT cv_help =help,cubeview
*/
{
  help,cubeview;
}

func cv_suspend(wdg, udata) {
/* DOCUMENT Cubeview SUSPEND button.

  Click button to suspend Cubeview. You can resume afeterwards using CV_RESUME.

*/
  if (cv_ui=="gtk") gy_gtk_suspend, _cvgy.toolbox;
  else {
    if (cv_stand_alone) quit;
    cv_freemouse;
  }
  write, "Cubeview suspended.";
  write, "Type \'cv\' to resume.";
  write, "Type \'quit\' to quit.";
}
  
func cv_splims(wdg, udata)
{
  extern cv_nodraw;
  if (cv_nodraw) return;
  cv_spwin;
  limits;
}

func cv_sllims(wdg, udata)
/* DOCUMENT cv_sllims & Cubeview's "Slice limits" button

     Sets the limits of Cubeview's slice window so that the full field
     is viewed, with squared pixels, and East on the left when world
     coordinates are in use.
*/
{
  extern cv_nodraw;
  if (cv_nodraw) return;
  extern cv_interns;
  x0=cv_interns.slpos(1);
  y0=cv_interns.slpos(2);
  x1=cv_interns.slpos(3);
  y1=cv_interns.slpos(4);
  /* if (abs(x1-x0) > abs(y1-y0)) {
     rap=abs(x1-x0)/abs(y1-y0);
     y1=y0+rap*(y1-y0);
     } else {
     rap=abs(y1-y0)/abs(x1-x0);
     x1=x0+rap*(x1-x0);
     }
     cv_slwin;
  limits,x0,x1,y0,y1;
  */
  cv_slwin;
  limits;
  limits,square=1;
  if (!cv_interns.pixel && x1 > x0) swap, x0, x1;
  limits,x0,x1,y0,y1;
}

/*
  func cv_error_handler {
  "error caught";
  resume;
  }
  extern after_error;
  after_error=cv_error_handler;
*/

func cubeview(data,slice_wid=,sp_wid=,cmd_wid=,origin=,scale=,depth=,overs=,
              slboxcol=,sltype=,slpalette=,slinterp=,zwlwise=,refwl=,
              waxis=,faxis=,vaxis=,zaxistype=,vlsr=,pixel=,hook=,spkeywords=,
              postinit=,xyaspect=, ui=)
/* DOCUMENT cubeview,data

   Cubeview is an  almost graphical package base on the  Tiny Widget Set (TWS),
   intended to allow easy access to spectroimaging data, or any 3D data.

   The only mandatory  argument, DATA, is either  a 3D array, or the  name of a
   FITS  file  containing such  a  cube. The  spectral  dimension  must be  the
   third. Actually if  you don't specify DATA, the program will  let you try to
   select a file, which is really fine only under ytk, in which case the tcl/tk
   file selection box is used. I don't find the text-only file selection helper
   really useable.
   
   Cubeview uses three windows, selectable through optional keywords:
     slice_wid=(0)   : the slice window
     spectrum_wid=(1): the spectrum window
     cmd_wid=(2)     : the command window, or tool bar.

   So Cubeview displays a  slice of the cube, which is really  an image made as
   the sum of  a few planes of the cube  and a spectrum, which is  the sum of a
   few individual spectra. The  slice can also be an RGB image  if you click on
   "3 color  slice". The  third window is  used to  display a few  buttons. The
   labels should be self-explanatory, but you can get help by right clicking on
   one of the buttons.

   Some buttons, like  the ones that let you select the  spectrum or the slice,
   remain active  (the text of the button  is then blue) untill  you finish the
   action  by either  right-clicking in  the relevant  window, or  clicking any
   button  in any  non-relevant  window.  The  "Slice  properties" and  "Spect.
   properties" buttons are a little special: when they are clicked, the command
   window is replaced  by a dialog box  in which you can choose  some eye candy
   properties  for  the slice  display,  and the  axis  type  for the  spectra.
   There's  no context  help available  in  these window,  right clicking  them
   reverts to the normal command box.

   Using the graphical frontend  to cubeview disables Yorick's standard zooming
   abilities. You can suspend Cubeview  by clicking on the appropiate button to
   re-enable them, or to perform any task on yorick's command line (like make a
   hardcopy  of the  windows...). You  then go  back to  your  running Cubeview
   session by typing  "cv_resume", or "cv" which is an  alias to cv_resume. The
   "limits" set this  this way are kept whil running cubeview,  that may not be
   what you want. You  can free the limits again, or only  the Y axis limits of
   the spectra, by clicking the appropriate buttons.

   Cubeview now  supports hooking  user function to  its drawing  routines. See
   source of cv_*_hook for sample usage.
   
   See CV_LIBRARY  for documentation about  the internals. All defaults  can be
   set through  cv_defaults, and overriden passing keywords  to cubeview. These
   keywords are the member names of the struture type CV_Interns.

   KEYWORDS: see CV_Interns, see postinit in cv_init.
        
   SEE  ALSO:   cv_library,  cv_init,  cv_defaults,   CV_Defaults,  cv_interns,
   CV_Interns
*/
{
  extern cv_ui;
  if (!is_void(ui)) cv_ui=ui;
  local slice_wid,sp_wid,cmd_wid,origin,scale,depth,overs,slbox,sltype,slpalette;
  if (!is_void(data)) {
    extern cv_gtk_no_init,cv_nodraw;
    cv_nodraw=1;
    cv_init,data,slice_wid=slice_wid,sp_wid=sp_wid,cmd_wid=cmd_wid,origin=origin,
      scale=scale,depth=depth,overs=overs,slboxcol=slbox,zwlwise=zwlwise,
      sltype=sltype,slpalette=slpalette,slinterp=slinterp,refwl=refwl,
      waxis=waxis,faxis=faxis,vaxis=vaxis,zaxistype=zaxistype,vlsr=vlsr,
      pixel=pixel,hook=hook,spkeywords=spkeywords,postinit=postinit,
      xyaspect=xyaspect;
    cv_nodraw=0;
    if (cv_ui=="gtk") {
      cv_gtk_no_init=1;
      cv_nodraw=1;
      cv_gtk;
    } else {
      cv_graphicwindows, 1;
    }
    if (cv_ui=="tws") cv_tws;
  } else cv_gtk;
}

func cv_tws(graphic_windows=)
/* DOCUMENT cv_tws or cv

     Resume a Cubeview almost graphical user interface session.

     While the event handler is runing, you don't have access to the command
     line to do anything not implemented in the GUI.

     Cubeview  allows you  to suspend  a session  by right  clicking  in its
     toolbar, and resume  whenever you want by calling  this simple routine.
     It may not  work if you do  weird things such as trying  to run another
     session  of Cubeview  or  any other  TWS  base software  (that is  only
     Cubeview for now...)

     If the  keyword GRAPHIC_WINDOWS is  set to a  non zero value,  then the
     slice  and spectrum  windows are  reset, which  is not  a good  idea if
     you've just spent half an hour trying to get the best zoom.

     cv is an alias to cv_resume
*/
{
  extern cv_interns;
  cv_cmd_win_init;
  if (!is_void(graphic_windows) && graphic_windows) cv_graphicwindows;
  tws_handler,cv_interns.root,"cv_handler";
  write,"Cubeview suspended.";
  write,"Call cv_resume (or simply cv) to resume.";
}

func cv_resume {
  if (cv_ui=="gtk") {
    extern cv_nodraw;
    cv_nodraw=1;
    cv_gtk;
  } else if (cv_ui=="tws") cv_tws;
}
cv=cv_resume;

func cv_graphicwindows(force,nokill=,extract=)
/* DOCUMENT cv_graphicwindows : redraw
   Argument:   if true, set cv_nodraw to 0.
   Keywords:   NOKILL:   if   set,   the   windows  are   not   killed   and
   re-initialized. EXTRACT: re-extract spectrum and slice.
 */
{
  extern cv_nodraw;
  if (force) cv_nodraw=0;
    if (extract){
            extern cv_interns;
            llx=cv_interns.spbox(1);
            lly=cv_interns.spbox(2);
            urx=cv_interns.spbox(3);
            ury=cv_interns.spbox(4);
            t1=min(cv_interns.sllims(1:2));
            t2=max(cv_interns.sllims(1:2));
            cv_slextract,t1,t2;
            cv_spextract,[llx,lly,urx,ury];
    }
    if (!nokill){
      if (cv_ui=="gtk") {
        gywindow, cv_interns.sp_wid,width=0,height=0,style="work.gs";//,
          //on_realize=cv_spdraw;
      } else {
        winkill,cv_interns.sp_wid;
        winkill,cv_interns.slice_wid;
        window,cv_interns.sp_wid,width=0,height=0,style="work.gs";
      }
    } else fma;
    cv_spdraw;
    if (!nokill){
      if (cv_ui=="gtk") {
        gywindow, cv_interns.slice_wid,width=0,height=0,style="work.gs";//,
        on_realize=cv_sldraw;
      } else {
        window, cv_interns.slice_wid,width=0,height=0,style="work.gs";
      } 
      cv_vpaspect,cv_interns.xyaspect;
    } else fma;
    cv_sldraw;
    if (!nokill) cv_sllims;
}

func cv_library
/* DOCUMENT cubeview, cv_init, cv_spsel,  cv_slsel, cv_cutsel and cv_cutreg are
   the main user level routines.

   Cubeview  is   a  set  of   routines  intended  to  ease   visualization  of
   spectroimaging  data. It  is consistant  in its  goals with  the  eponym IDL
   package from the BEAR project.

      cubeview,data starts an almost graphical user interface. If you just want
                    to  look at  3D data,  just  kick it  off, and  right-click
                    buttons to get context help. Left click them to use them.
   
   Data are  shared between routines through an  external variable, cv_interns,
   of type CV_Interns. Function names begin with "cv_". Defaults are defined in
   an external variable, cv_defaults, of type CV_Defaults.

   The main goal is to display both a slice and a spectrum in two windows.

   It is possible  to hook a user  routine to some events. To  do this, just
   set cv_interns.hook to  a string containing the name  of the user routine
   (say,  "MyHook"). This  can  be done  by  means of  the  HOOK keyword  to
   cubeview and cv_init.  Each time  a cv_ function that supports hooking is
   called, the  user function with  get called with  the name of  the caller
   routine as  a single argument: for  instance MyHook("cv_spdraw") whenever
   the  spectrum  gets  redrawn.   The  user function  should  make  use  of
   cv_interns to get any data it  needs.  Grep the source for cv_callhook to
   find out which routines support hooking.
   
   Main routines:
     cv_init,data: initiates  external variables and windows. Data
                   should be either a FITS file name or a 3D data cube.
     cv_spsel:     select spectrum in a rectangular area with mouse.
     cv_slsel:     select slice on the spectrum with mouse.
     cv_cutsel:    select minimum and maximum value to show (see CMIN and CMAX
                   in bytscl).
     cv_cutreg:    enclose a rectangular area with mouse, CMIN and CMAX will
                   be min and max in this area.
     cv_cutregonce: same as cv_cutreg, but just once and not interactively.

   Intermediate level routines:
     cv_slextract,begin,end:  explicitely extract a slice from plane BEGIN to plane END
     cv_spextract,corners:    explicitely extract a spectrum from a given rectangular aperture
     cv_sldraw and cv_spdraw: explicitely redraw slice or spectrum. Can extract as well.
     cv_slwin and cv_spwin:   explicitely select slice or spectrum window.
     cv_cutregonce:           same as cv_cutreg, but just once and not interactively.

   Helper routines:
     cv_slpnm,filename: write the current slice to a PNM file.
     cv_blank: "blank" selected volume (setting it to the value specified by
               the BLANK card of the fits file).
     
   For the low level routines, use the source.
     
   Cubeview GUI is based on the Tiny Widget Set (TWS).
     
   Note: cv_library itself  is a function that does  nothing more than showing
   its own DOCUMENT comment.

   SEE ALSO: cubeview, cv_interns, cv_defaults, CV_Interns, CV_Defaults, cv_library
*/
{
  help,cv_library;
}

func cv_3colscale(slice,cmin=,cmax=)
{
  f=slice(sum,,);
  scl=(cmax-cmin)/255.;
  shift=cmin/scl;
  c=f/scl-shift;
  if (min(c) < 0) {
    ind=where(c<0);
    c(ind)=0;
  }
  if (max(c) > 255) {
    ind=where(c>255);
    c(ind)=255;
  }
  for (p=1;p<4;p++) slice(p,,)=cv_divima(c,f)*slice(p,,);
  return char(slice);
}

func cv_divima(a,b)
{
  ind=where(b!=0);
  c=b;
  c(ind)=a(ind)/b(ind);
  return c;
}

func cv_rgbfilters(n,type=)
{
  if (is_void(type) || type=="rainbow") {
    x=[         0,          7,        45,         81,        119,     155,      192,          200]/200.*n;
    curves=[[255,0,42.],[255,0,0],[255,255,0],[0,255,0],[0,255,255],[0,0,255],[255,0,255],[255,0,201]];
    xp=indgen(n);
    filters=array(double,3,n);
    if (cv_interns.zwlwise==1) for (i=1;i<4;i++) filters(i,)=interp(curves(i,),x,xp(n:1:-1));
    else for (i=1;i<4;i++) filters(i,)=interp(curves(i,),x,xp);
  }
  return filters;
}

func cv_readbb(file)
/* DOCUMENT box=cv_readbb(filename)

returns bounding box of an eps file.
*/
{
  f=open(file);
  llx=lly=urx=ury=long();
  while (ury==0) read,f,llx,lly,urx,ury,format="%%%%BoundingBox: %d %d %d %d";
  return [llx,lly,urx,ury];
}


func cv_rgbeps(prefix)
/* DOCUMENT cv_rgbeps & Cubeview "Slice -> epsi" button.
            cv_rgbeps,prefix

     In  the second  form, outputs  Cubeview's current  slice to  an  epsi file
     PREFIX.epsi (.epsi is appended to  PREFIX). In the first form, prompts for
     PREFIX  and performs.   When  prompted,  action is  canceled  if you  type
     "cancel" as a prefix.

     cv_rgbeps uses  a number of external  programs, so works only  on UNIX, if
     the programs  are installed:  convert (from ImageMagick),  jpeg2ps, latex,
     dvips  and ps2epsi.   A number  of temporary  files are  written,  but not
     deleted: (in the following, ~ means PREFIX) ~_axes.ps, ~_im.pnm, ~_im.jpg,
     ~_im.eps, ~.tex, ~.aux, ~.dvi, ~.ps  and ~.epsi. The file your looking for
     is PREFIX.epsi. Afterwards, you can  modify PREFIX_im.eps and run latex on
     PREFIX.tex again... So the intermediate files  can come in handy. And as a
     side effect, you  also get pnm, jpg and eps versions  of the image without
     the axes...

     The point  of all this is  that, at least  on my machine, Yorick  does not
     produce good  RGB eps files, or  I don't know how  to do it. So  I cheat a
     little bit.   By the way,  this is mostly  usefull for 3 color  slices. It
     works on normal  slices, producing RGB eps (using  pnm_colorize), that may
     or may  not be  what you  want.  For normal  slices, I  suggest suspending
     Cubeview,  switching to  the slice  window  with CV_SLWIN,  and using  the
     standard EPS function.

     Note that you  can also tell Cubeview  to display 3 color images  at 8 bit
     depth  (by setting cv_interns.depth  to 8  instead of  24). In  that case,
     running EPS  manually as  mentioned above works  great. The colors  may be
     less impressive when a large dynamic  is needed, but this way you can also
     get the spectrum window with its nice rainbow slice box...

     So in a word, this is here  to take care of the most complicated case, but
     there are other  simpler means to get the picture,  that may be preferable
     in most cases.

     Here is a cookbook to get things at 8bit depth:

     1) get your picture interactively at 24bit depths, including the cuts.
     2) suspend Cubeview.
     3) switch to 8bit depth: cv_interns.depth=8
     (3bis: at this point, you may notice  that the cut aren't to great, you can
      resume Cubeview(cv) to fix them, and suspend again. Screen update does not
      work to great at 8bit though)
     4) redraw both windows: cv_graphicwindows
     5) zoom in with the mouse if you whish...
     6) switch to slice window: cv_slwin
     7) dump it to eps file: eps,"filename_slice"
     8) switch to spectrum window: cv_spwin
     9) dump it to eps file: eps,"filename_spectrum"
     10) get back to 24bit display: cv_interns.depth=24 ; cv_graphicwindows;
     11) resume Cubeview: cv
*/
{
  extern cv_interns;
  require,"pnm.i";
  require,"coords.i";
  if (is_void(prefix)) {
    prefix="cv_rgbeps";
    write,"Select a prefix to write a few files. I will erase:";
    write,"<prefix>_axes.ps, ~_im.pnm, ~_im.jpg, ~_im.eps, ~.tex, ~.aux, ~.dvi, ~.ps and ~.epsi.";
    write,"The file you want is <prefix>.epsi.";  
    read,prompt="Select a prefix (\"cancel\" to cancel): ",format="%s",prefix;
    if (prefix=="cancel") return 1;
  }
  cv_slwin;
  if (cv_interns.sltype=="3 color") im=bytscl(cv_oversamp(*cv_interns.slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
  else if (cv_interns.sltype=="Normal") im=pnm_colorize(cv_oversamp(*cv_interns.slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
  pnm_write,im,prefix+"_im.pnm";
  fma;
  plg,0,0;
  cv_sllims;
  hcps,prefix+"_axes";
  get_style,land,sys,leg,cleg;
  vp=sys(1).viewport;
  system,"convert "+prefix+"_im.pnm "+prefix+"_im.jpg";
  system,"jpeg2ps "+prefix+"_im.jpg > "+prefix+"_im.eps";
  //  system,"psfixbb -f -o "+prefix+"_axes.eps "+prefix+"_axes.ps";
  bb=cv_readbb(prefix+"_axes.ps");
  width=ndc2cm(vp(2)-vp(1));
  height=ndc2cm(vp(4)-vp(3));
  xpos=inch2cm(ndc2inch(vp(1))-bb(3)/72.); // note: a PS pt is 1/72 inch, but a yorick (or LaTeX) is 1/72.27
  ypos=inch2cm(ndc2inch(vp(3))-bb(2)/72.);
  f=open(prefix+".tex","w");
  write,f,format="%s","\\documentclass{article}\n";
  write,f,format="%s","\\usepackage{a4wide}\n";
  write,f,format="%s","\\usepackage{graphicx}\n";
  write,f,format="%s","\\usepackage{pstricks}\n";
  write,f,format="%s","\\begin{document}\n";
  write,f,format="%s","\\pagestyle{empty}\n";
  write,f,format="%s","\\includegraphics{"+prefix+"_axes.ps}%\n";
  write,f,format="\\rput[bl]{0}(%g,%g){\\includegraphics[width=%gcm,height=%gcm]{%s_im.eps}}\n",xpos,ypos,width,height,prefix;
  write,f,format="%s","\\end{document}\n";
  close,f;
  system,"latex "+prefix+".tex";
  system,"dvips -o "+prefix+".ps "+prefix+".dvi";
  //  system,"psfixbb -f -o "+prefix+".eps "+prefix+".ps";
  system,"ps2epsi "+prefix+".ps";
}

func cv_pnm(prefix)
/* DOCUMENT cv_pnm,"filename"

     Writes current slice to pnm file.
*/
{
  extern cv_interns;
  require,"pnm.i";
  require,"coords.i";
  while (is_void(prefix)) {
    prefix="cv_pnm.pnm";
    write,"Select a name for pnm output.";
    read,prompt="Filename (\"cancel\" to cancel): ",format="%s",prefix;
    if (prefix=="cancel") return 1;
  }
  cv_slwin;
  if (cv_interns.sltype=="3 color") im=bytscl(cv_oversamp(*cv_interns.slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
  else if (cv_interns.sltype=="Normal") im=pnm_colorize(cv_oversamp(*cv_interns.slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
  pnm_write,im,prefix;
}

func cv_rgb2indexed(image, &red, &green, &blue, size=, flip=)
/* DOCUMENT cv_rgb2indexed, image, red, green, blue

     Converts RGB image  to indexed color image. This  function is identical to
     pnm_display in pnm.i,  except it does not plot, but  returns the image and
     palette  components. This  routines intends  not to  touch the  display in
     anyway (for instance it does not set the palette.)

     RED, GREEN and BLUE are returned  arrays to feed PALETTE with.  (Unlike in
     PNM_DISPLAY, they are not returned in an external variable.)

   SEE ALSO: pnm_display, cv_library
 */
{
  if (is_void(size)) size= 200;
  if (typeof(image)!="char") image= bytscl(image,top=255);

  r= image(1,,);
  g= image(2,,);
  b= image(3,,);

  /* count cells in 16x16x16 subcubes of full RGB color cube */
  rgb= (long(r>>4) | (g&0xf0) | ((b&0xf0)<<4)) + 1;
  hist= histogram(rgb,top=4096);

  /* the size available colors must be shared among occupied subcubes
     -- allocate them in order of occupation */
  order= map= sort(-hist);
  map(order)= indgen(0:4095);
  c= order-1;
  cr= char(c<<4)+'\10';
  cg= char(c&0xf0)+'\10';
  cb= char((c>>4)&0xf0)+'\10';

  //  extern red, green, blue;
  red= cr(1:size);
  green= cg(1:size);
  blue= cb(1:size);

  map= char(map);
  pal= long([red,green,blue])(,-,);
  pic= long([cr,cg,cb])(-,,);
  for (i=size+1 ; i<=4096 && hist(order(i)) ; i=k+1) {
    k= min(i+7, 4096);
    map(order(i:k))= ((pal-pic(,i:k,))^2)(,,sum)(mnx,)-1;
  }

  rgb= map(rgb);
  if (flip) rgb= rgb(,::-1);

  return rgb;
}

func cv_oversamp(im)
{
  extern cv_interns;
  fact=cv_interns.overs;
  if (fact == 1 | fact == 0) return im;
  
  dims=dimsof(im);
  xd=dims(1)-1;
  yd=xd+1;
  nx=dims(xd+1);
  ny=dims(yd+1);
  nnx=cv_lround(fact*(nx-1)+1);
  nny=cv_lround(fact*(ny-1)+1);
  x=indgen(nx);
  y=indgen(ny);
  xp=span(min(x),max(x),nnx);
  yp=span(min(y),max(y),nny);
  if (cv_interns.slinterp=="interp") {
    im2=interp(im,x,xp,xd);
    im3=interp(im2,y,yp,yd);
  } else if (cv_interns.slinterp=="spline") {
    if (dims(1)==2) {
      im2=array(double,nnx,ny);
      im3=array(double,nnx,nny);
      for (j=1;j<=ny;j++) im2(,j)=spline(im(,j),x,xp);
      for (i=1;i<=nnx;i++) im3(i,)=spline(im2(i,),y,yp);
    } else if (dims(1)==3) {
      im2=array(double,3,nnx,ny);
      im3=array(double,3,nnx,nny);
      for (b=1;b<=3;b++) {
        for (j=1;j<=ny;j++) im2(b,,j)=spline(im(b,,j),x,xp);
        for (i=1;i<=nnx;i++) im3(b,i,)=spline(im2(b,i,),y,yp);
      }
    }
  }
  return im3;
}

func cv_newrefwl(refwl)
/* DOCUMENT cv_newrefwl,refwl

     Change   Cubeview's  reference   wavelength:  set   cv_interns.refwl  and
     *cv_interns.vaxis.

*/
{
  if (refwl) {
    cv_interns.refwl=refwl;
    cv_interns.vaxis=&(voflambda(*cv_interns.waxis,refwl)/1000.); // km/s
  }
}

func cv_blank(rien){
/* DOCUMENT cv_blank

  Puts zeros in the currently selected 3D box. Useful for cleaning.

*/
    extern cv_interns;
    llx=long(cv_interns.spbox(1));
    lly=long(cv_interns.spbox(2));
    urx=long(cv_interns.spbox(3));
    ury=long(cv_interns.spbox(4));
  t1=min(cv_interns.sllims(1:2));
  t2=max(cv_interns.sllims(1:2));
  cv_cube(llx:urx,lly:ury,t1:t2)=0.;
  cv_graphicwindows,extract=1,nokill=1;
}

func cv_gauss_smooth(sp,fwhm){
/* DOCUMENT sm=cv_gauss_smooth(sp,fwhm)

    Gaussian smoothing of a spectrum or image.

   SEE ALSO: box_smooth
*/
    sm=sp;
    if (fwhm!=0) {
        dims=dimsof(sp);
        b=fwhm*1./(2.*sqrt(2*log(2)));
        total=b*sqrt(2*pi);
        if (dims(1)==1){
            s=numberof(sp);
            kernel=gauss(span(0,s*2-1,s*2),[1.,s,b]);
            kernel=kernel/total;
            for(k=0;k<s;k++) {
                lk=kernel(s-k+1:2*s-k)/kernel(sum:s-k+1:2*s-k);
                sm(k+1)=sum(lk*sp);
            }
        } else if (dims(1)==2){
            for (i=1;i<=dims(2);i++) sm(i,)=cv_gauss_smooth(sp(i,),fwhm);
            for (j=1;j<=dims(3);j++) sm(,j)=cv_gauss_smooth(sm(,j),fwhm);
        }
    }
    return sm;
}

func cv_vpaspect(x,y) {
/* DOCUMENT cv_vpaspect,x,y
         or cv_vpaspect,x/y
         or cv_vpaspect,data

    Set  the  viewport  of  current  graphic  window  so  that  it  has  the
    appropriate aspect  ratio to display an  XxY image.  In  the third form,
    data  may be  a 2-or-more  dimensional array,  and it  is  equivalent to
    cv_vpaspect,dimsof(data(2)),dimsof(data(3)).

    Note  that the new  viewport always  fits in  the old  one, so  that the
    viewport gets  smaller and smaller  as you set  it again and  again with
    cv_vpaspect. Use vpset to change the size of the viewport.

   SEE ALSO: vpset, coords.i, style.i, get_style, set_style
*/
    if (is_void(y)) {
        if (is_scalar(x)) {
            y=1.;
        } else {
        // Assume we've been given an image (or cube)
            sz=dimsof(x);
            x=sz(2);
            y=sz(3);
        }
    }
    get_style, land, sys, leg, cleg;
    xc=0.397;
    yc=0.639;
    fact=0.00065;
    xs=sys(1).viewport(2)-sys(1).viewport(1);
    ys=sys(1).viewport(4)-sys(1).viewport(3);
    if (abs(x) > abs(y)) {
        rap=abs(x)/double(abs(y));
        ys=xs/rap;
    } else {
        rap=abs(y)/double(abs(x));
        xs=ys/rap;
    }
    sys(1).viewport=[xc,xc,yc,yc]+[-xs,xs,-ys,ys]/2.;
    set_style, land, sys, leg, cleg;
}

func cv_plfi(im,x0,y0,x1,y1)
/* DOCUMENT cv_plfi,im
            cv_plfi,im,x1,y1
            cv_plfi,im,x0,y0,x1,y1

      Draws an RGB image using plf. Syntax  similar to PLI, except im has to be
      3xNxM of thype char (an RGB image).

      This is to work around a bug that prevents RGB images from being properly
      output to eps (or ps or epsi...) when using pli.

      SEE ALSO: plf, pli
*/
{
  dims=dimsof(im);
  if (is_void(x0)) {
    x0=0;
    y0=0;
    x1=dims(3);
    y1=dims(4);
  } else if (is_void(x1)) {
    x1=x0;
    y1=y0;
    x0=y0=0;
  }
  X=array(span(x0,x1,dims(3)+1),dims(4)+1);
  Y=transpose(array(span(y0,y1,dims(4)+1),dims(3)+1));
  plf,im,Y,X;
}

func cv_zoom(factor) {
/* DOCUMENT cv_zoom

   A zoom  similar to  that provided directly  by yorick.  left,  middle and
   left click zoom-in, pan and  soom-out respectively; when control is hold,
   button  1 zooms on  drawn rectangle,  buttons 2  and 3  zoom out  so that
   viewport is  downscaled to drawn rectangle (unlike  default zoomer). When
   control is hold, normal zoom  is perform dragging low-left to high-right:
   other combination  cause one or both  of the axes to  be inverted (unlike
   default zoomer).

   Click in another window to stop.

   See also: limits
*/
  extern cv_nodraw;
  if (cv_nodraw) return;
    if (is_void(factor)) factor=1.5;
    resume;
    results=cv_mouse(1,1,"");
    while (results(10)!=0) {
        x_pressed=results(1);
        y_pressed=results(2);
        x_released=results(3);
        y_released=results(4);
        xndc_pressed=results(5);
        yndc_pressed=results(6);
        xndc_released=results(7);
        yndc_released=results(8);
        msystem=results(9);
        button=results(10);
        modifiers=results(11);

        old_limits=limits();
        llx=llx0=old_limits(1);
        urx=urx0=old_limits(2);
        lly=lly0=old_limits(3);
        ury=ury0=old_limits(4);

        // normalised pressed coordinates
        xpn=(x_pressed-llx0)/(urx0-llx0);
        ypn=(y_pressed-lly0)/(ury0-lly0);
        
        if (xpn > 0 && xpn < 1) dox=1; else dox=0;
        if (ypn > 0 && ypn < 1) doy=1; else doy=0;
        
        if (modifiers==4) {
            if (button==1) {
                // just zoom on the box
                if (dox && doy) limits,x_pressed,x_released,y_pressed,y_released;
                else if (dox) limits,x_pressed,x_released;
                else if (doy) range,y_pressed,y_released;
            } else {
                // zoom out current view into the box
                //x and y scale factors
                if (dox) {
                    xscale=(x_released-x_pressed)/(urx0-llx0);
                    llx=llx0-(x_pressed-llx0)/xscale;
                    urx=llx+(urx0-llx0)/xscale;
                }
                if (doy) {
                    yscale=(y_released-y_pressed)/(ury0-lly0);
                    lly=lly0-(y_pressed-lly0)/yscale;
                    ury=lly+(ury0-lly0)/yscale;
                }
                limits,llx,urx,lly,ury;
            }
        } else {
            if (button==1) scale=factor;
            else if (button==2) scale=1;
            else if (button==3) scale=1./factor;
            if (dox) {
                llx=x_pressed-(x_released-llx0)/scale;
                urx=x_pressed+(urx-x_released)/scale;
            }
            if (doy) {
                lly=y_pressed-(y_released-lly0)/scale;
                ury=y_pressed+(ury-y_released)/scale;
            }
            limits,llx,urx,lly,ury;
        }
        resume;
        results=cv_mouse(1,1,"");
    }
}

func cv_mouse(msystem, style, prompt) {
  cv_interns.mouselock=1;
  res=mouse(msystem, style, prompt);
  cv_interns.mouselock=0;
  return res;
}


func cv_save_sel(outfileo) {
  /* DOCUMENT cv_save_sel, filename

      Save the subecube currently selected in cubeview (both spectral
      and spatial dimension) to file FILENAME, updating the FITS
      header if possible.
  
   */

  cv_set_aperture,"rectangular";
  low=cv_interns.sllims(1);
  high=cv_interns.sllims(2);
  llx=long(cv_interns.spbox(1));
  lly=long(cv_interns.spbox(2));
  urx=long(cv_interns.spbox(3));
  ury=long(cv_interns.spbox(4));

  header=_cpy(cv_fh);
  if (header) {
    NAXIS3=high-low+1;
    incr=[llx,lly,low]-1;
    for (n=1;n<=3;n++) {
      sn=pr1(n);
      CRPIX=fits_get(header,"CRPIX"+sn,default="not set");
      if (CRPIX!="not set") fits_set,header,"CRPIX"+sn,CRPIX-incr(n);
    }
    if (is_bear(header)) {
      FSR_OFF=fits_get(header,"FSR_OFF",default=0)+low-1;
      fits_set,header,"FSR_OFF",FSR_OFF;
      FSR_LEN=fits_get(header,"FSR_LEN",default=dimsof(cv_cube)(4));
      fits_set,header,"FSR_LEN",FSR_LEN;
    }
  }
  //  if (is_gzipped(outfileo)) outfile=strpart(outfileo,:-3); else outfile=outfileo;
  fits_write,outfileo,cv_cube(llx:urx,lly:ury,low:high),template=header,overwrite=1;
  //  if (is_gzipped(outfileo)) gzip,outfile;

}

func cv_circmas(sx,sy,x,y,r,inv=){
/* DOCUMENT cv_circmas(sx,sy,x0,y0,r,inv=)
    returns a circular mask,  i.e. a 2D array MASK of size  SXxSY, of type int,
    such that for any (x,y),
      - if    INV    is    not    set    (or    null):    (MASK(x,y)==1)    <=>
        sqrt((x-x0)^2+(y-y0)^2)<=r.
      - if INV is set, (MASK(x,y)==1) <=> sqrt((x-x0)^2+(y-y0)^2)>r;
*/
  xx=array(double(indgen(sx))-x,sy);
  yy=transpose(array(double(indgen(sy))-y,sx),0);
  d2=xx^2+yy^2;
  if (inv) return (d2 > r^2);
  else return (d2 <= r^2);
}

func cv_freemouse {
  if (cv_interns.mouselock) {
    cv_interns.mouselock=0;
    rien=mouse(,,">> Exiting mouse-lock, please ignore following error message");
  }
}

func cv_export_misc(fname,format,what,savedata,selonly) {
  if (is_void(format)) {
    bname=basename(fname);
    ext=pathsplit(bname,delim=".");
    if (numberof(ext)==1) {
      cv_warning,"Export failed: format not specified.";
      return;
    }
    format=strcase(1,ext(0));
    if (anyof(format==["TXT", "DAT", "CSV"])) format="ASCII";
    if (anyof(format==["JPG", "JFIF"])) format="JPEG";
    if (anyof(format==["PPM"])) format="PNM";
  }
  if (savedata) {
    if (what=="slice") {
      slice=*cv_interns.slice;
      if (selonly) {
        cv_set_aperture,"rectangular";
        llx=long(cv_interns.spbox(1));
        lly=long(cv_interns.spbox(2));
        urx=long(cv_interns.spbox(3));
        ury=long(cv_interns.spbox(4));
        slice=slice(..,llx:urx,lly:ury);
        // SHOULD UPDATE NAXIS*
      }
      if (format=="FITS") {
        fits_write,fname,slice,overwrite=1;
      } else if (format=="PNG") {
        im24=bytscl(cv_oversamp(slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
        if (cv_interns.sltype=="3 color") {
          im=cv_rgb2indexed(im24,red,green,blue);
        } else if (cv_interns.sltype=="Normal") {
          cv_slwin;
          palette, red,green,blue,gray,query=1;
          im=im24;
        }
        remove,fname;
        png_write,fname,im,palette=transpose([red,green,blue]);
      } else if (format=="JPEG") {
        if (cv_interns.sltype=="3 color") {
          im=bytscl(cv_oversamp(slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
        } else if (cv_interns.sltype=="Normal") {
          cv_slwin;
          im=pnm_colorize(cv_oversamp(slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
        }
        remove,fname;
        jpeg_write,fname,im(,,0:1:-1);
      } else if (format=="PNM") {
        if (cv_interns.sltype=="3 color") {
          im=bytscl(cv_oversamp(slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
        } else if (cv_interns.sltype=="Normal") {
          cv_slwin;
          im=pnm_colorize(cv_oversamp(slice),cmin=cv_interns.cmin,cmax=cv_interns.cmax);
        }
        remove,fname;
        pnm_write,im,fname;
      }
    } else {
      spectrum=*cv_interns.spectrum;
      header=_cpy(cv_fh);
      if (selonly) {
        low=cv_interns.sllims(1);
        high=cv_interns.sllims(2);
      } else {
        low=1; high=numberof(spectrum);
      }
      spectrum=spectrum(low:high);
      if (format=="FITS") {
        if (header) {
          incr=low-1;
          CRPIX = fits_get(header,"CRPIX3");
          CRVAL = fits_get(header,"CRVAL3");
          CDELT = fits_get(header,"CDELT3");
          CTYPE = fits_get(header,"CTYPE3",default="not set");
          if (is_numerical(CRPIX)) fits_set,header,"CRPIX1",CRPIX-incr;
          else fits_delete,header,"CRPIX1";
          if (is_numerical(CRVAL)) fits_set,header,"CRVAL1",CRVAL;
          else fits_delete,header,"CRVAL1";
          if (is_numerical(CDELT)) fits_set,header,"CDELT1",CDELT;
          else fits_delete,header,"CDELT1";
          if (CTYPE!="not set") fits_set,header,"CTYPE1",CTYPE;
          else fits_delete,header,"CTYPE1";
          fits_delete,header,"CRPIX2";
          fits_delete,header,"CRVAL2";
          fits_delete,header,"CDELT2";
          fits_delete,header,"CTYPE2";
          fits_delete,header,"CRPIX3";
          fits_delete,header,"CRVAL3";
          fits_delete,header,"CDELT3";
          fits_delete,header,"CTYPE3";
          if (is_bear(header)) {
            FSR_OFF=fits_get(header,"FSR_OFF",default=0)+low-1;
            fits_set,header,"FSR_OFF",FSR_OFF;
            FSR_LEN=fits_get(header,"FSR_LEN",default=dimsof(cv_cube)(4));
            fits_set,header,"FSR_LEN",FSR_LEN;
          }
        }
        fits_write,fname,spectrum,template=header,overwrite=1;
      } else if (format=="ASCII") {
        axis=(*cv_current_zaxis())(low:high);
        fh=open(fname,"w");
        write,fh,axis,spectrum;
        close,fh;
      }
    }
  } else cv_export_plot,fname,what,format=format;
}

func cv_export_plot(fname,what,format=) {
  if (!is_void(what)) {
    if (what=="slice") cv_slwin;
    if (what=="spectrum") cv_spwin;
  }
  if (is_void(format)) {
    bname=basename(fname);
    ext=pathsplit(bname,delim=".");
    if (numberof(ext)==1) {
      cv_warning,"Export failed: format not specified.";
      return;
    }
    format=ext(0);
  }
  fformat="cv_unkown_format";
  if (anyof(format==["JPEG","jpeg","jpg","jfif"])) fformat="jpeg";
  else if (anyof(format==["PNG","png"])) fformat="png";
  else if (anyof(format==["EPS","eps"])) fformat="eps";
  else if (anyof(format==["PDF","pdf"])) fformat="pdf";
  if (is_func(symbol_def(fformat))) junk=symbol_def(fformat)(fname);
  else cv_warning,"Export failed: "+fformat+" function not available in this Yorick.";
}

func cv_unkown_format(fname){
  cv_warning,"File format not recognized for file name "+fname;
}

func cv_warning(msg){
  if (cv_ui=="gtk") gyerror, msg;
  else print, msg;
}

func cv_is_osiris(fh) {
  if (is_string(fh)) pfh = fits_open(fh);
  else {
    pfh = _cpy(fh);
    fits_rewind, pfh;
  }
  if (fits_get(pfh, "CURRINST") == "OSIRIS") return 1;
  return 0;
}

func cubeview3(caller)
/* DOCUMENT cubeview3, caller

    This is a cubeview hook to overplot spectra extracted from two
    supplementary cubes in addition to the main cv_cube. Use
    cubeview3_connect to connect this hook.

   SEE ALSO: cubeview, cubeview3_connect
 */
{
  extern cv_interns, cube2, cube3;
  if (caller=="cv_spdraw") {
    plh, color="blue", cv_spextract(,&cube2), (*cv_current_zaxis());
    plh, color="red", cv_spextract(,&cube3), (*cv_current_zaxis());
  }
}

func cubeview3_connect(c2, c3)
/* DOCUMENT cubeview3_connect, cube2, cube3
         or cubeview, cube1, hook=cubeview3_connect(cube2, cube3)

    Connect the cubeview3 hook to cubeview, which overplots spectra
    extracted from CUBE2 and CUBE3 whenever cubeview redraws its
    spectrum plot.  In the first (procedural) form, cubeview must be
    already running.  The second (functional) form allows connecting
    the hook directly when invoking cubeview. The three cubes must
    have the same shape.
     
   SEE ALSO: cubeview, cubeview3
 */
{
  extern cube2, cube3;
  cube2 = c2;
  cube3 = c3;
  if (am_subroutine())  cv_interns.hook="cubeview3";
  else return "cubeview3"; 
}


extern cv_stand_alone, cv_hdu;
cv_stand_alone=0;
cv_hdu=1;

cv_args=get_argv();
if (is_void(CV_NO_AUTO) & numberof(cv_args)>=3 && anyof(basename(cv_args(3))==["cubeview.i","cubeview"])) {
  if (numberof(cv_args)>3) {
    cv_args=cv_args(4:);
    ind=where(strgrep("^-",cv_args)(2,)==-1);
    if (numberof(ind)) cv_filename=cv_args(ind(1));
    if (numberof(ind)<numberof(cv_args)) {
      ind=where(strgrep("^--",cv_args)(2,)!=-1);
      cv_options=cv_args(ind);
      for (o=1;o<=numberof(cv_options);o++) {
        option=cv_options(o);
        pos=strfind("=",option);
        key=strpart(option,3:pos(1));
        if (pos(2)==-1) value= "true"; else value=strpart(option,pos(2)+1:);
        if (key == "stand-alone") {
          if (anyof(value==["true","1","TRUE","T","yes","t"])) cv_stand_alone=1;
          else cv_stand_alone=0;
        } else if ( key == "pixel" ) {
          if (anyof(value==["true","1","TRUE","T","yes","t"]))
            cv_defaults.pixel=1;
          else cv_defaults.pixel=0;
        } else if ( key == "hdu" ) {
          sread, format="%i", value, cv_hdu;
        }
        else if (key == "ui") cv_ui=value;
      }
    }
  }
  if (cv_stand_alone) batch, 1;
  if (!is_void(cv_filename)) cubeview,cv_filename;
  else cv_gtk;
}
