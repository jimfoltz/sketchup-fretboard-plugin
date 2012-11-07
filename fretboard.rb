# Copyright 2008 www.guitar-list.com
# version 1.2.1 02-04-2008

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------

require 'sketchup.rb'

#-----------------------------------------------------------------------------

# This script creates a conical tapered fretboard.
# When you run this function, it will display a dialog box which prompts
# for the dimensions of the fretboard, and then creates the fretboard.

#draw the points on a circle sector centred on y=0, x=x and z=radius-thickness
def get_curve_points(radius,width,thickness,x, resolution)
    pts = []
    sect = 2.0*Math.asin(width / (2.0 * radius))    
    b = thickness - radius  
    da = sect / resolution
    startangle = - resolution / 2
    endangle = resolution + startangle + 1
    pi2 = 1.5707963267948966192313216916398
    for i in startangle...endangle do
        angle = pi2 + (i * da)
        y = 0 + radius*Math.cos(angle)
        z = b + radius*Math.sin(angle)
        if z < 0.0 
          z=0.0
        end
        pts.push (Geom::Point3d.new(x,y,z))
    end
    pts
end

def get_fret_side(d,nutradius,nutwidth,bodyradius,bodywidth,boardlength,boardthickness,tangdepth,res)
        fretradius = nutradius + ( d*(bodyradius-nutradius))/boardlength
        fretwidth = nutwidth + ( d*(bodywidth-nutwidth))/boardlength
        #top of fret groove
        fretpts = []
        fretpts = get_curve_points(fretradius,fretwidth,boardthickness,boardlength-d,res)
        #underneath fret groove
        fretpts2 = []
        fretpts2 = get_curve_points(fretradius,fretwidth,boardthickness-tangdepth,boardlength-d,res)
        j=0        
        while j <= res
          fretpts.push(fretpts2[res-j])
          j += 1
        end
        fretpts
end

def rect_face(pts0,pts1,pts2,pts3)
    #triangulate a rectangular face
    base = $boardentities.add_face pts0,pts1,pts3
    base = $boardentities.add_face pts0,pts2,pts3
end

def create_fretboard
    # First prompt for the dimensions.  
    prompts = [$exStrings.GetString("Scale Length"), $exStrings.GetString("Width at nut"), 
    $exStrings.GetString("Radius at nut"), $exStrings.GetString("Width at body"), 
    $exStrings.GetString("Radius at body"),  $exStrings.GetString("Board thickness"),
    $exStrings.GetString("No. of frets"),$exStrings.GetString("Depth of fret slot"), 
    $exStrings.GetString("width of fret slot"),$exStrings.GetString("width of nut slot"),
    $exStrings.GetString("depth of nut slot") ]
    #default values - in  inches
    values = [25.0, 2.38, 18.0, 3.0, 20.0, 0.23, 22, 0.023, 0.023, 0.125, 0.125]
    
    # Now display the inputbox
    results = inputbox prompts, values, $exStrings.GetString("Fretboard Dimensions")

    return if not results # This means that the user cancelled the operation
    scalelength, nutwidth, nutradius, bodywidth, bodyradius, boardthickness, fretcount, tangdepth, tangwidth,nutslotwidth,nutslotdepth = results
    
    model = Sketchup.active_model   
    model.start_operation $exStrings.GetString("Create Fretboard")
    model.layers.add("Fretboard")
	  model.active_layer= model.layers["Fretboard"]
    $boardentities = model.entities
    
    #calculate the length of the fret board 
    boardlength = scalelength - (scalelength / (2.0 **( (fretcount + 1) / 12.0) ))

    ptsbody = []
    ptsnut = []
    #res is the number of line components making up each curve - use an even number
    res = 16
    ptsbody = get_curve_points(bodyradius,bodywidth,boardthickness-tangdepth,0,res)
    ptsnut = get_curve_points(nutradius,nutwidth,boardthickness-tangdepth,boardlength,res) 
       
    #body end plane of fretboard
    wb = bodywidth/2.0
    pts = []
    pts[0] = [0,-wb, 0] 
    pts[1] = [0,wb, 0]
    ptsbody.push(pts[0])
    ptsbody.push(pts[1])
    base = $boardentities.add_face ptsbody 
  
    #nut end plane of fretboard
    pts = []
    wn = nutwidth/2.0 
    pts[0] = [boardlength,-wn, 0]
    pts[1] = [boardlength,wn, 0]
    ptsnut.push(pts[0])
    ptsnut.push(pts[1])
    base = $boardentities.add_face ptsnut
    
    #flat bottomed nut slot and part of fingerboard behind the nut
    if (nutslotwidth>0) 
      pts = []
      pts[0] = [boardlength,-wn, 0]
      pts[1] = [boardlength,wn, 0]
      pts[2] = [boardlength,wn, boardthickness-nutslotdepth]
      pts[3] = [boardlength,-wn, boardthickness-nutslotdepth]
      
      base = $boardentities.add_face pts 
      base.pushpull nutslotwidth
      
      pts = []
      pts = get_curve_points(nutradius,nutwidth,boardthickness,boardlength+nutslotwidth,res)
      pts.push([boardlength+nutslotwidth,-wn, 0])
      pts.push([boardlength+nutslotwidth,wn, 0])
      base = $boardentities.add_face pts 
      base.pushpull nutslotwidth*4
    end
    
    #underneath of fretboard
    rect_face([0,-wb, 0],[0,wb, 0],[boardlength,-wn,0 ],[boardlength,wn,0 ])
   
    #sides of fretboard
    rect_face(ptsbody[res],[0,-wb,0],ptsnut[res],[boardlength,-wn,0])
    rect_face(ptsbody[0],[0,wb,0],ptsnut[0],[boardlength,wn,0])
    
    model.layers.add("Fret_slots")
	  fretptslast = []
    #draw fret grooves
    for i in 0 ... fretcount+1 do
        d1 = scalelength - (scalelength / (2.0 **( i / 12.0) ))
        d2 = scalelength - (scalelength / (2.0 **( (i+1) / 12.0) ))
        if i>0
          d1 = d1 + tangwidth / 2.0
        end
        if i<(fretcount)
          d2 = d2 - tangwidth / 2.0
        end
        fretpts = get_fret_side(d1,nutradius,nutwidth,bodyradius,bodywidth,boardlength,boardthickness,tangdepth,res)
        fretpts2 = get_fret_side(d2,nutradius,nutwidth,bodyradius,bodywidth,boardlength,boardthickness,tangdepth,res)
        model.active_layer= model.layers["Fret_slots"]
        face  = $boardentities.add_face fretpts
        if (tangwidth>0)
          face  = $boardentities.add_face fretpts2
           #curved bottom of fret slots
          if (fretptslast.length>0)
            j = res+1
            res.times {
              rect_face(fretpts[j],fretpts[j+1],fretptslast[j],fretptslast[j+1])
              j += 1
            }
          end
        end
        fretptslast = fretpts2
        #fingerboard in between fret slots
        model.active_layer= model.layers["Fretboard"]
        j = 0
        res.times {
            rect_face(fretpts[j],fretpts[j+1],fretpts2[j],fretpts2[j+1])
            j += 1
        }      
        rect_face(fretpts.first,fretpts.last,fretpts2.first,fretpts2.last)
        rect_face(fretpts[res],fretpts[res+1],fretpts2[res],fretpts2[res+1])
    end
    # We're finished we can end the operation
    model.commit_operation
end

# First check to see if we have already loaded this file so that we only 
# add the item to the menu once
if( not file_loaded?("fretboard.rb") )

    # This will add a separator to the menu, but only once
    add_separator_to_menu($exStrings.GetString("Draw"))
    # To add an item to a menu, you identify the menu, and then
    # provide a title to display and a block to execute.  
    UI.menu($exStrings.GetString("Draw")).add_item($exStrings.GetString("fretboard")) { create_fretboard }

end

#-----------------------------------------------------------------------------
file_loaded("fretboard.rb")
