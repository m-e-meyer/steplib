/*
STEPLIB: ASH library for running a script as a sequence of steps

This library allows a script to be run and rerun as a sequence of numbered steps.  The steps
do not have to be numbered consecutively, but they must be run in order.  If a script aborts
in one step, then rerunning the script will skip all steps preceding that step, so the second
run will start with the step that failed.  Convenient!  

Steps represent actions that must not be repeated if the script is run again.  For example, 
your script may require eating foods with specific properties in order, call them A, B, and C, 
after which the player is full.  Eating each food is a step.  If something goes wrong between
B and C, you can fix the problem and rerun the script.  Steps A and B will be skipped because
they've already been done, and you will eat C, as is supposed to happen.

Each step is represented by a "step function".  A step function is a function that takes 0,
1, 2, 3, or 4 string arguments and returns a boolean.  The step function must return true if
the step was successful, and false otherwise.  The library will abort the script if the step
function returns false.  

NOTE: A step function cannot be invoked as a step from another step function invoked as a 
step; this is a runtime error.  In other words, steps cannot be nested.  However, a step
function NOT invoked as a step can invoke a step function as a step, and vice versa.
*/

int MAX_INT = 2147483647;

string STEP_PREFIX = "";        // Prefix set by your script for all step property names
string STEP_ASCENSION = "";     // Property recording ascension in which script last run
string STEP_PREV_STEP = "";     // Property recording number of last step completed
string STEP_CURRENT = "";       // Property recording step currently being done; used to
                                // prevent step nesting
                                
// You can use the following property, named STEP_PREFIX+"_stopBeforeStep", for debugging 
string STEP_STOP_BEFORE = "";   // execution will stop before doing this step

/*
get_step_property: Returns the value of the named property.
Arguments:
    name: string name of the property
    defaultt: int default value to return if the property is empty
Returns the current value of the property, or the given default if the property is empty
*/
int get_step_property(string name, int defaultt)
{
    string val = get_property(name);
    if (val == "")
        return defaultt;
    else
        return to_int(val);
}

/*
begin_steps: Procedure that must be called at the beginning of your script.  It initializes
             the stepping properties.
Arguments:
    prefix: string you choose to prefix all step property names for your script
    once_per_ascension: true if the steps are intended to run once per ascension, else false
*/
void begin_steps(string prefix, boolean once_per_ascension)
{
    if (prefix == "")
        abort("Step prefix must not be empty.  Aborting.");
    // Create step property key strings
    STEP_PREFIX = prefix;
    STEP_ASCENSION = STEP_PREFIX + "_ascension";
    STEP_PREV_STEP = STEP_PREFIX + "_lastStepDone";
    STEP_STOP_BEFORE = STEP_PREFIX + "_stopBeforeStep";
    STEP_CURRENT = STEP_PREFIX + "_currentStep";
    // Get last completed step
    int last_ascension = get_step_property(STEP_ASCENSION, -1);
    int prev_step = get_step_property(STEP_PREV_STEP, MAX_INT);
    // Reset to beginning only if previous run is complete 
    // AND (this is not once per ascension OR the last steps were in a prev asc)
    
    if (last_ascension < my_ascensions()) {
        // First time ever done in this ascension - start at beginning
        set_property(STEP_ASCENSION, my_ascensions());
        set_property(STEP_PREV_STEP, 0);
    } else {
        // Last one was in this ascension
        if (prev_step == MAX_INT) {     
            // If last run finished, check whether we can start another run
            if (once_per_ascension)
                abort("These steps have already been completed for this ascension.");
            // If not once per ascension, start at beginning
            set_property(STEP_ASCENSION, my_ascensions());
            set_property(STEP_PREV_STEP, 0);
        }
        // Else run is not finished; do not change state
    }
}

/*
end_steps: Procedure that must be called at the end of your script.  It sets the previous
           step to MAX_INT so no more steps can be run.
Arguments:
    prefix: string you choose to prefix all step property names for your script;
            MUST match what you passed to begin_steps()!
*/
void end_steps(string prefix)
{
    set_property(STEP_PREV_STEP, MAX_INT);
}

/*
__step__: Base function for performing a step.  The user does not call this function, but 
          rather calls the functions below.
Arguments:
    seqnum: int designating the step number.  Must be between 1 and MAX_INT-1 inclusive,
            otherwise step() will abort
    fn: string name of the step function to call (see introduction above)
    argc: int number of arguments to pass to the step function
    arg1, arg2, arg3, arg4: string arguments to pass to the step function
*/
void __step__(int seqnum, string fn, int argc, 
              string arg1, string arg2, string arg3, string arg4)
{
    // If STEP_PREFIX has not been set by begin_steps, it's an error
    if (STEP_PREFIX == "")
        abort("begin_steps() not run.  Aborting.");
    // If the sequence number is nonpositive or the maximum integer, error
    if (seqnum <= 0 || seqnum == MAX_INT)
        abort("step sequence number " + seqnum + " out of range.  Aborting.");
        
    try {
        // If we're inside another step, it's a runtime error.  There is no good way to
        // handle all possibilities for this case, so we give up.
        if (get_property(STEP_CURRENT) != "")
            abort("Can't start step " + seqnum + " while still doing step "
                  + get_property(STEP_CURRENT) + ".  Aborting.");
        // Flag that we're doing a step
        set_property(STEP_CURRENT, to_string(seqnum));
        // If this step is or is before last step done, do nothing
        int last_done = get_step_property(STEP_PREV_STEP, MAX_INT);
        if (seqnum <= last_done)
            return;
        // If this step is or is after the stopping point, abort
        int stop_before = get_step_property(STEP_STOP_BEFORE, MAX_INT);
        if (stop_before <= seqnum)
            abort("Execution halted before step " + seqnum + " - user breakpoint reached");
        // Do step, and abort if status comes back false
        boolean status;
        switch (argc) {
            case 0 : status = call boolean fn();  break;
            case 1 : status = call boolean fn(arg1);  break;
            case 2 : status = call boolean fn(arg1, arg2);  break;
            case 3 : status = call boolean fn(arg1, arg2, arg3);  break;
            case 4 : status = call boolean fn(arg1, arg2, arg3 , arg4);  break;
            default:  abort("Invalid value to step: argc=" + argc);
        }
        if (!status)
            abort("Step " + seqnum + " returned bad status.");
        // If all is well, mark step done
        set_property(STEP_PREV_STEP, seqnum);
    } finally {
        // We are no longer doing this step, so clear the flag
        set_property(STEP_CURRENT, "");
    }
}


// Perform a step with no arguments
void step(int seqnum, string fn)
{
    __step__(seqnum, fn, 0, "", "", "", "");
}

// Perform a step with one argument
void step(int seqnum, string fn, string arg1)
{
    __step__(seqnum, fn, 1, arg1, "", "", "");
}

// Perform a step with two arguments
void step(int seqnum, string fn, string arg1, string arg2)
{
    __step__(seqnum, fn, 2, arg1, arg2, "", "");
}

// Perform a step with three arguments
void step(int seqnum, string fn, string arg1, string arg2, string arg3)
{
    __step__(seqnum, fn, 3, arg1, arg2, arg3, "");
}

// Perform a step with four arguments
void step(int seqnum, string fn, string arg1, string arg2, string arg3, string arg4)
{
    __step__(seqnum, fn, 4, arg1, arg2, arg3, arg4);
}
