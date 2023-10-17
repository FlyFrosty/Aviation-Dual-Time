import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;
import Toybox.Time.Gregorian;
import Toybox.Time;
import Toybox.ActivityMonitor;

class AviationDualTimeView extends WatchUi.WatchFace {

    //Load the text formats
    var mainView;           //Big, top time
    var mainViewShaddow;

    var stepDisplay;
    var stepString = "0";     //The number of steps to be displayed

    var noteDisplay;
    var alarmDisplay;
    var batteryDisplay;
    var dateCalc;

    var zuluTime;           //The 24 hour formatted corrected from zulu time
    var myZuluLabel;        //User selected offset from Z formatted for display
    var dispZuluTime;

    var mainZuluOffset;     //The display for the ammount of zulu offset
    var subZuluOffset;      //The lower zulu offset display

    var calcTime;           //Formatted local time

    
    
    function initialize() {
        WatchFace.initialize();
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

    }


    // Update the view
    function onUpdate(dc as Dc) as Void {

        notesAlarms();
                
        battDisp();

        dateDisp();

        mainZone();   

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
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
        var convLeftoverOffset = (offSetAmmt % 10) * 360;     //Convert any partial hour part to seconds
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
    

    //Notifications And Alarms Display Area
    function notesAlarms() {
        noteDisplay = View.findDrawableById("noteLabel") as Text;
        alarmDisplay = View.findDrawableById("alarmLabel") as Text;

        var noteString=" ";
        var alarmString=" ";
        var avSets = System.getDeviceSettings();

        if (avSets.notificationCount !=0) {
            noteString = "N";
        } else {
            noteString = " ";
        }
        noteDisplay.setText(noteString);

        if (avSets.alarmCount != 0) {
            alarmString = "A";
        } else {
            alarmString = " ";
        }
        alarmDisplay.setText(alarmString);
    } 


    //Battery Display Area
    function battDisp() {
        //Get battery info
        var batString;
        batteryDisplay = View.findDrawableById("batLabel") as Text;

        if (showBat == 0) {
    
            var batLoad = ((System.getSystemStats().battery) + 0.5).toNumber();
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
        var stepLoad = ActivityMonitor.getInfo();
        var steps = stepLoad.steps;

        stepString = Lang.format("$1$", [steps]);
    }


    //Date Area
    function dateDisp() {

        dateCalc = View.findDrawableById("dateLabel") as Text;

        var dateLoad = Time.Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateString = Lang.format("$1$, $2$ $3$", 
            [dateLoad.day_of_week,
            dateLoad.day,
            dateLoad.month]);

        dateCalc.setColor(subColorSet);
        dateCalc.setText(dateString);
    }
     

    //Main Time Area
    function mainZone() {
    //Choose Main display, set colors and show
        mainView = View.findDrawableById("mainTimeAreaLabel") as Text;
        mainViewShaddow = View.findDrawableById("mainTimeAreaShadLabel") as Text;
        dispZuluTime = View.findDrawableById("zTimeLabel") as Text;
        mainZuluOffset = View.findDrawableById("zuluLabel") as Text;
        subZuluOffset = View.findDrawableById("subZuluLabel") as Text;
        stepDisplay = View.findDrawableById("stepLabel") as Text;

        normalTime();
        calcZuluTime();
        makeZuluLabel();

        mainView.setColor(clockColorSet);
        mainViewShaddow.setColor(clockShadSet);
        mainZuluOffset.setColor(clockColorSet);
        dispZuluTime.setColor(subColorSet);
        subZuluOffset.setColor(subColorSet);
        stepDisplay.setColor(subColorSet);

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
                subZuluOffset.setText(" ");
                stepsDisp();
                stepDisplay.setText(stepString);
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
                stepDisplay.setText(stepString);
            }
        }


    } 

}
