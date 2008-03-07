/*
    $Id: bear.i,v 1.1 2008-03-07 10:03:02 paumard Exp $
    
    bear.i
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
func _bear_fits_get(fh,key) {
  if (is_array(fh)) {
    res=fitsHdrValue(fh,key);
    if (typeof(res)=="string" && res=="Not a Keyword") res=[];
  } else res=fits_get(fh,key);
  return res;
}
func bear_faxis(fh,P=,CEN_FREQ=,FILTERLB=,FILTERUB=,FSR_OFF=,FSR_LEN=,NAXIS3=,SPAXIS=){
/* DOCUMENT bear_faxis

    Returns frequency axis for a BEAR data set in cm-1.

    INPUTS: fh: FITS file handle of a BEAR cube or spectrum as used in
    fits.i or header array as used in newfits.i.

    KEYWORDS:
     P,CEN_FREQ,FILTERLB,FILTERUB,FSR_OFF,FSR_LEN,NAXIS3,SPAXIS

    As keywords  override FITS cards,  it is not  necessary to provide fh  if a
    sufficient number of keywords are given.

    Necessary information is:
     P ;
     CEN_FREQ: central frequency,  or indeed any frequency in  the FSR, defaults
      to (FILTERLB+FILTERUB)/2;
     NAXIS3: number of points in  the spectral dimension, which is determined by
      SPAXIS;
     SPAXIS: index  of the  spectral dimension, defaults  to the last  one (FITS
      card "NAXIS");
     FSR_OFF: offset between FSR ad cube, defaults to 0;
     FSR_LEN: number of planes in the FSR, defaults to NAXIS3.

    FITS cards used:
     P,FILTERLB,FILTERUB,FSR_OFF,FSR_LEN,NAXISn,NAXIS
*/
        if (is_void(P)) P  = _bear_fits_get(fh,"P ");
        if (is_void(CEN_FREQ)) {
            if (is_void(FILTERLB)) FILTERLB = _bear_fits_get(fh,"FILTERLB");
            if (is_void(FILTERUB)) FILTERUB = _bear_fits_get(fh,"FILTERUB");
            CEN_FREQ = (FILTERLB+FILTERUB)/2.;
        }
        if (is_void(FSR_OFF)) if (!is_void(fh)) FSR_OFF = _bear_fits_get(fh,"FSR_OFF");
        if (is_void(FSR_LEN)) if (!is_void(fh)) FSR_LEN = _bear_fits_get(fh,"FSR_LEN");
        if (is_void(NAXIS3)) {
            if (is_void(SPAXIS)) SPAXIS = _bear_fits_get(fh,"NAXIS");
            NAXIS3 = _bear_fits_get(fh,"NAXIS"+pr1(SPAXIS));
        }

    if (is_void(FSR_OFF)) FSR_OFF=0;
    if (is_void(FSR_LEN)) FSR_LEN=NAXIS3;
    
    dfcm = 1./(2.*double(P)*(6.3299141e-5)/8.) ;//dfcm = Delta_frequency in cm-1
    fmin = floor( CEN_FREQ / dfcm) * dfcm ; //minimum frequency of the FSR
    fmax = fmin+dfcm ;
    faxis=span(fmin,fmax,FSR_LEN)(FSR_OFF+1:FSR_OFF+NAXIS3);
    //if (((floor(CEN_FREQ/dfcm)) mod 2)==0) rev=0 else rev=1; //rev is computed in cubeview for IDL, but never used: obsolete ??

    return faxis;

}

func is_bear(fh){
/* DOCUMENT is_bear(fh)

    Tells if FITS header FH belongs to a BEAR data set, using FITS
    card "INSTRUME".

*/
  if (is_array(fh)) {
    inst=fitsHdrValue(fh,"INSTRUME",default="other");
  } else {
    inst=_bear_fits_get(fh,"INSTRUME");
    if (is_void(inst)) inst="other";
  }  
    if (strtrim(inst)=="bear") return 1;
    return 0;
}
