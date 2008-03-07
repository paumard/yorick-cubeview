/*
  $Id: check.i,v 1.1 2008-03-07 10:03:02 paumard Exp $
  
  A check/example file for Cubeview.
    This file is part of Cubeview.
    Copyright (C) 2007  Thibaut Paumard <paumard@users.sourceforge.net>

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

// Setting NO_CV_AUTO prevents cubeview from starting automatically
NO_CV_AUTO=1;
#include "cubeview.i"
NO_CV_AUTO=[];

"Creating a sample cube...";
lambda=span(2.05,2.07,201);
vel=voflambda(lambda,2.058)/1000.;
xx=array(span(1,64,64),64);
yy=transpose(xx);
cube=(gauss(xx,[1.,20.,2.])*gauss(yy,[1.,20.,2.]))(,,-)*lambda(-,-,);
cube+=(gauss(xx,[1.,20.,2.])*gauss(yy,[1.,20.,2.]))(,,-)*gauss(vel,[-2,-100,50])(-,-,);
cube+=(gauss(xx,[1.,20.,2.])*gauss(yy,[1.,20.,2.]))(,,-)*gauss(vel,[1,0,100])(-,-,);
cube+=(gauss(xx,[0.5,50.,2.])*gauss(yy,[0.5,40.,2.]))(,,-)*lambda(-,-,);
cube+=(gauss(xx,[1.,50.,2.])*gauss(yy,[1.,40.,2.]))(,,-)*gauss(vel,[1,100,500])(-,-,);
cube+=gauss(vel(-,-,)-(3*xx+2*yy)(,,-),[1,0.,10]);

fname="cubeview-test.fits";
write,format="Creating FITS file %s\n",fname;
fh=fits_create(fname,bitpix=-32,overwrite=1);

write,format="%s\n","Creating minimal header";
fits_set, fh,"CTYPE3","WAVE";
fits_set, fh,"CRPIX3",0.;
fits_set, fh,"CRVAL3",2.05;
fits_set, fh,"CDELT3",0.0001;

write,format="%s\n","Writing data";
fits_write,fname,cube,template=fh,overwrite=1;

"Launching Cubeview.";
"You should see - an image window representing two 'stars';";
"               - a spectrum window;";
"               - and a GTK toolbox.";
"Play with the toolbox. Closing it will quit Yorick.";
cv_stand_alone=1;
cubeview,"cubeview-test.fits",ui="gtk",refwl=2.058;
