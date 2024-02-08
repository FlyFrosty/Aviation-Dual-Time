//Change color fewer times by moving the assignments?

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time.Gregorian;
import Toybox.Time;
import Toybox.ActivityMonitor;
import Toybox.Complications;


    var mainView;           //Big, top time
    var mainViewShaddow;        
    var dispZuluTime;

    var mainZuluOffset;     //The display for the ammount of zulu offset
    var subZuluOffset;      //The lower zulu offset display

    var colorsUpdated = true;   //A Check to see if we need to run the updateColors

class AviationDualTimeView extends WatchUi.WatchFace {

    //Load the text formats


    var stepDisplay;
    var stepString = "0";     //The number of steps to be displayed
    var stepId;
    var stepComp;
    var mSteps;         //For the non-complications watches

    var noteId;
    var noteComp;
    var noteSets;
    var noteDisplay;

    var wxId;
    var wxComp;
    var wxNow;

    var alarmDisplay;   //No complications for this

    var dateCalc;

    var zuluTime;           //The 24 hour formatted corrected from zulu time
    var myZuluLabel;        //User selected offset from Z formatted for display
 
    var calcTime;           //Formatted local time

    var hasComps = false;

    var batteryDisplay;
    var batString;
    var batId;
    var batComp;
    var batLoad = 0;

    var calId;          //Calendar info for new watches only
    var calComp;

    var batY = 0.33;        //Divide up the screen for press to complications
    var stepY = 0.66;
    var wHeight;
    
    
    function initialize() {
        WatchFace.initialize();

        hasComps = (Toybox has :Complications); 

        if (hasComps) {
            stepId = new Id(Complications.COMPLICATION_TYPE_STEPS);
            batId = new Id(Complications.COMPLICATION_TYPE_BATTERY);
            calId = new Id(Complications.COMPLICATION_TYPE_CALENDAR_EVENTS);
            noteId = new Id(Complications.COMPLICATION_TYPE_NOTIFICATION_COUNT);
            wxId = new Id(Complications.COMPLICATION_TYPE_CURRENT_TEMPERATURE);

            stepComp = Complications.getComplication(stepId);
            if (stepComp != null) {
                Complications.subscribeToUpdates(stepId);
            }

            batComp = Complications.getComplication(batId);
            if (batComp != null) {
                Complications.subscribeToUpdates(batId);  
            }

            noteComp = Complications.getComplication(noteId);
            if (noteComp != null) {
                Complications.subscribeToUpdates(noteId);
            } 

            wxComp = Complications.getComplication(wxId);
            if (wxComp != null) {
                Complications.subscribeToUpdates(wxId);
            }

            Complications.registerComplicationChangeCallback(self.method(:onComplicationChanged));         
        }    
    }

    function onComplicationChanged(compId as Complications.Id) as Void {

        if (compId == batId) {
            batLoad = (Complications.getComplication(batId)).value;
            if (batLoad == null) {
                batLoad = ((System.getSystemStats().battery) + 0.5).toNumber();
            }
        } else if (compId == stepId) {
            mSteps = (Complications.getComplication(stepId)).value;
            if (mSteps == null){
                var stepLoad = ActivityMonitor.getInfo();
                mSteps = stepLoad.steps;
            }
            if (mSteps instanceof Toybox.Lang.Float) {
                mSteps = (mSteps * 1000).toNumber(); //System converts to float at 10k. Reported system error
            }
        } else if (compId == noteId) {
            noteSets = (Complications.getComplication(noteId)).value;
            if (noteSets == null) {
                var tempNotes = System.getDeviceSettings();
                noteSets = tempNotes.notificationCount;
            }
        } else if (compId == wxId) {
            wxNow = (Complications.getComplication(wxId)).value;
            if (wxNow == null) {
               wxNow = -99; 
            }
        } else {
            System.println("no valid comps");
        }
    }


    // Load your resources here
    function onLayout(dc as Dc) as Void {
        
        setLayout(Rez.Layouts.WatchFace(dc));

        mainView = View.findDrawableById("mainTimeAreaLabel") as Text;
        mainViewShaddow = View.findDrawableById("mainTimeAreaShadLabel") as Text;
        stepDisplay = View.findDrawableById("stepLabel") as Text;
        noteDisplay = View.findDrawableById("noteLabel") as Text;
        alarmDisplay = View.findDrawableById("alarmLabel") as Text;
        batteryDisplay = View.findDrawableById("batLabel") as Text;
        dateCalc = View.findDrawableById("dateLabel") as Text;
        dispZuluTime = View.findDrawableById("zTimeLabel") as Text;
        mainZuluOffset = View.findDrawableById("zuluLabel") as Text;
        subZuluOffset = View.findDrawableById("subZuluLabel") as Text;

        wHeight = dc.getHeight();           //used for touch scren areas

    }


    // Update the view
    function onUpdate(dc as Dc) as Void {

        if (showNotes) {
            notesDisp();
        } else {
            noteDisplay.setText(" ");
        }

        alarmDisp();
                
        battDisp();

        dateDisp();

        mainZone(dc);   

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);

        if (dispSecs && 
                System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND) {
            secondsDisplay(dc);
        }
    }
    
    function normalTime() {
    //Created formated local time

        var clockTime = System.getClockTime();
        var hours = clockTime.hour;

        //Calc local time for 12 or 24 hour clock
        if (System.getDeviceSettings().is24Hour == true){      
            calcTime = Lang.format("$1$:$2$", [clockTime.hour.format("%02d"), clockTime.min.format("%02d")]);
        } else {
            if (hours > 12) {
                hours = hours - 12;
            }
            calcTime = Lang.format("$1$:$2$", [hours, clockTime.min.format("%02d")]);
        }
    }



    function calcZuluTime() {
    //24 hour clock only
            
        var zTime = Time.Gregorian.utcInfo(Time.now(), Time.FORMAT_MEDIUM);
        var myOffset = zTime.hour;
        var minOffset = zTime.min;

        //Offset to add or subtract
        var convLeftoverOffset = (offSetAmmt % 10) * 360;     //Convert any partial hour to seconds
        var convToOffset = ((offSetAmmt / 10) - 13) * 3600;    //Convert the hours part to seconds

        convToOffset = convToOffset + convLeftoverOffset; //Total Offset in seconds
            
        //Convert Zulu time to seconds
        var zuluToSecs =  (minOffset * 60) + (myOffset * 3600);

        //Combine the offset with the current zulu
        var convToSecs = convToOffset + zuluToSecs;

        //Keep the new offset time positive (no negative time)
        if (convToSecs <= 86400) {
            myOffset = ((86400 + convToSecs) - ((86400 + convToSecs)%3600)) / 3600;
        } else {
            myOffset = ((convToSecs) - ((86400 + convToSecs)%3600)) / 3600;
        }

        //Adjust mins and hours for clock rollovers due to add or sub 30 min
        minOffset = (convToSecs % 3600) / 60;

        if (minOffset < 0) {
            minOffset = minOffset + 60;
        }   

        //correct for hours within the 24 hour clock
        if (myOffset == 24) {
            myOffset = 0;
        } else if (myOffset < 0) {
            myOffset = myOffset + 24;
        } else if (myOffset >= 24) {
            myOffset = myOffset - 24;
        }

        zuluTime = Lang.format("$1$:$2$", [myOffset.format("%02d"), minOffset.format("%02d")]);  
    }   
    

    function makeZuluLabel() {    
    //If Zulu time, do the else part

        if (offSetAmmt != 130) {
            //Prep the label
            var myParams;
            var myFormat = "Set $1$+$2$";

            if (offSetAmmt % 10 != 0) {
                if ((offSetAmmt - 130) < 0) {
                    myParams = [((offSetAmmt / 10) - 12), (offSetAmmt % 10 * 6)];
                } else {
                    myParams = [((offSetAmmt / 10) - 13), (offSetAmmt % 10 * 6)];
                }
            } else {
                myParams = [((offSetAmmt / 10) - 13), "00"];
            }
                
            myZuluLabel = Lang.format(myFormat,myParams);

        } else {
            myZuluLabel = "Zulu";
        }      
    }
    

    //Notifications Display Area
    function notesDisp() {

        var anyNotes;
        var noteString=" ";

        if (hasComps == false) {
            noteSets = System.getDeviceSettings();

            if (noteSets.notificationCount !=0) {
                anyNotes = true;
            } else {
                anyNotes = false;
            }
        } else {
            if (noteSets != 0) {
                anyNotes = true;
            } else {
                anyNotes = false;
            }
        }

        if (anyNotes) {
            noteString = "N";
        } else {
            noteString = " ";
        }
        noteDisplay.setText(noteString);
    }


    function alarmDisp() {

        var alarmString=" ";

        var alSets = System.getDeviceSettings().alarmCount;

        if (alSets != 0) {
            alarmString = "A";
        } else {
            alarmString = " ";
        }
        alarmDisplay.setText(alarmString);
    } 


    //Battery Display Area
    function battDisp() {
        //Get battery info

        if (hasComps && showBat == 2) {
            batteryDisplay.setColor(subColorSet);
            if (ForC == System.UNIT_METRIC) {
                batString = Lang.format("$1$", [wxNow])+"°";
            } else {
                wxNow = wxNow * 9 / 5 + 32;
                batString = Lang.format("$1$", [wxNow])+"°";
            }
        } else if (showBat == 0) {

            if (!hasComps) {
                batLoad = ((System.getSystemStats().battery) + 0.5).toNumber();
            }
            batString = Lang.format("$1$", [batLoad])+"%";

            if (System has :SCREEN_SHAPE_SEMI_OCTAGON &&
                System.getDeviceSettings().screenShape != System.SCREEN_SHAPE_SEMI_OCTAGON){     //Monocrhrome correction

                if (batLoad < 5.0) {
                    batteryDisplay.setColor(Graphics.COLOR_RED);
                } else if (batLoad < 25.0) {
                    batteryDisplay.setColor(Graphics.COLOR_YELLOW);
                } else {
                    batteryDisplay.setColor(Graphics.COLOR_DK_GREEN);
                }
            } else {

                if (myBackgroundColor == 0xFFFFFF) {
                    batteryDisplay.setColor(Graphics.COLOR_BLACK);
                } else {
                    batteryDisplay.setColor(Graphics.COLOR_WHITE);
                }
            }
        } else { 
            batString = " ";
            batteryDisplay.setColor(Graphics.COLOR_TRANSPARENT);
        }
        batteryDisplay.setText(batString);    
    }


    function stepsDisp() {
    //Format Steps
        var stepLoad;  

        if (!hasComps) {
            stepLoad = ActivityMonitor.getInfo();
            mSteps = stepLoad.steps;
        }

        stepString = Lang.format("$1$", [mSteps]);
        stepDisplay.setText(stepString); 

    }


    //Date Area
    function dateDisp() {

        var dateLoad = Time.Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$, $2$ $3$", 
            [dateLoad.day_of_week,
            dateLoad.day,
            dateLoad.month]);

        dateCalc.setText(dateString);
    }

    function secondsDisplay(dc) {

        var screenWidth = dc.getWidth();
        var screenHeight = dc.getHeight();
        var centerX = screenWidth / 2;
        var centerY = screenHeight / 2;
        var mRadius = centerX < centerY ? centerX - 4: centerY - 4;
        var clockTime = System.getClockTime();
        var mSeconds = clockTime.sec;

        var mPen = 4;

        var mArc = 360 - (mSeconds * 6);

        dc.setPenWidth(mPen);
        dc.setColor(clockColorSet, Graphics.COLOR_TRANSPARENT);
        dc.drawArc(centerX, centerY, mRadius, Graphics.ARC_CLOCKWISE, 90, mArc);

    }
     

    //Main Time Area
    function mainZone(dc) {
    //Choose Main display, set colors and show

        normalTime();
        calcZuluTime();
        makeZuluLabel();

        if (colorsUpdated) {
            mainView.setColor(clockColorSet);
            mainViewShaddow.setColor(clockShadSet);
            mainZuluOffset.setColor(clockColorSet);
            dispZuluTime.setColor(subColorSet);
            subZuluOffset.setColor(subColorSet);
            stepDisplay.setColor(subColorSet);
            dateCalc.setColor(subColorSet); 

            colorsUpdated = false;
        }

        if (localOrZulu) {
        //Normal display here  

            mainZuluOffset.setText(" "); //Clear residual

            mainView.setText(calcTime);
            mainViewShaddow.setText(calcTime);

            if (timeOrStep) {
                //Display Secondary time

                stepDisplay.setText(" ");       //Clear Steps
            
                dispZuluTime.setText(zuluTime);
                subZuluOffset.setText(myZuluLabel);

            } else {
                //Display Stpes

                dispZuluTime.setText(" ");  //Clear residual
                subZuluOffset.setText("steps");
                stepsDisp();
            }

        } else {
        //Inverted display code here

            mainView.setText(zuluTime);
            mainViewShaddow.setText(zuluTime);

            if (timeOrStep) {
            //Display secondary time

                stepDisplay.setText(" ");           //clear residual
                subZuluOffset.setText("Local");         //Clear residual

                dispZuluTime.setText(calcTime);
                mainZuluOffset.setText(myZuluLabel);
            } else {
                subZuluOffset.setText(" ");         //Clear residual
                dispZuluTime.setText(" ");          //Clear residual
                stepsDisp();
            }
        }


    } 

}

class AviationDualTimeDelegate extends WatchUi.WatchFaceDelegate
{
	var view;
	
	function initialize(v) {
		WatchFaceDelegate.initialize();
		view=v;	
	}

    function onPress(evt) {
        var c=evt.getCoordinates();
        var batY = view.batY * view.wHeight;
        var stepY = view.stepY * view.wHeight;

        if (c[1] <= batY) {

            if (showBat == 0 && view.batId != null) {
                Complications.exitTo(view.batId);
                return true;
            } else if (showBat == 2 && view.wxId != null) {
                Complications.exitTo(view.wxId);
                return true;
            } else {
                return false;
            }

        } else if (c[1] > batY && c[1] <= stepY && view.calId != null) {
            Complications.exitTo(view.calId);
            return true;
        } else if (view.stepId != null) {
            Complications.exitTo(view.stepId);
            return true;
        } else {
            return false;
        }
    }
	
}
