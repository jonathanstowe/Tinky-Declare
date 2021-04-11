use v6;

=begin pod

=head1 NAME

Tinky::Declare -  Declarative creation of Tinky machines

=head1 SYNOPSIS

This is the functional equivalent to the L<Tinky synopsis|https://github.com/jonathanstowe/Tinky/blob/master/README.md#synopsis>:

=begin code

use Tinky;
use Tinky::Declare;

class Ticket does Tinky::Object {
    has Str $.ticket-number = (^100000).pick.fmt("%08d");
    has Str $.owner;
}

my $workflow = workflow 'ticket-workflow', {
    initial-state 'new';
    workflow-state 'new';
    workflow-state 'open';
    workflow-transition 'open', 'new', 'open';

    workflow-state 'rejected' , {
        on-enter -> $object {
            say "** sending rejected e-mail for Ticket '{ $object.ticket-number }' **";
        }
    }

    workflow-transition 'reject', 'new', 'rejected';
    workflow-transition 'reject', 'open','rejected';
    workflow-transition 'reject', 'stalled','rejected';

    workflow-state 'in-progress';
    workflow-state 'stalled';

    workflow-transition 'stall', 'open', 'stalled';
    workflow-transition 'stall', 'in-progress', 'stalled', {
        on-apply-transition -> $object {
            say "** rescheduling tickets for '{ $object.owner }' on ticket stall **";
        }
    }

    workflow-state 'completed';

    workflow-transition 'unstall', 'stalled', 'in-progress';
    workflow-transition 'take', 'open', 'in-progress';
    workflow-transition 'complete', 'open', 'complete';
    workflow-transition 'complete', 'in-progress', 'complete';

    on-transition -> ( $transition, $object ) {
        say "Ticket '{ $object.ticket-number }' went from { $transition.from.name }' to '{ $transition.to.name }'";
    }

    on-final-state -> ( $state, $object) {
        say "** updating performance stats with Ticket '{ $object.ticket-number }' entered State '{ $state.name }'"
    }

};

my $ticket-a = Ticket.new(owner => "Operator A");

$ticket-a.apply-workflow($workflow);

$ticket-a.open;

$ticket-a.take;

$ticket-a.next-states>>.name.say;

$ticket-a.state = $workflow.state('stalled');

$ticket-a.reject;

=end code

=head1 DESCRIPTION

This provides a declarative interface to create L<Tinky|https://github.com/jonathanstowe/Tinky> 'workflow' objects.
You probably want to familiarise yourself with the L<Tinky documentation|https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md>
to get an idea of what is going on under the hood.

Essentially it creates a small DSL that allows you to create a L<Tinky::Workflow|https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkyworkflow>
populated with the L<State|https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkystate> and L<Transition|https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkystate>
objects that describe the workflow.  Because the underlying objects are created for you only those features of Tinky that don't require
sub-classing are exposed, such as tapping the supplies for leaving and entering a state (or all states,) the application of a transition (or all transitions,)
and application of the workflow to an object, as well as L<validation callbacks|https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#subset-validatecallback>
for all of those events.

=end pod

module Tinky::Declare {
    use Tinky;

    #| This is a sub-class of Tinky::Workflow
    #| that provides some extra functionality that is required to create and find the states and transitions by name.
    class Workflow is Tinky::Workflow {
        #| Gets the named state or undefined type object
        method state(Str:D $state --> Tinky::State) {
            self.states.first({ $_ ~~ $state }) // Tinky::State;
        }

        has Tinky::State @.states;

        #| This over-rides the Tinky::Workflow because the states will be populated as they are seen.
        #| The behaviour of the base version in the absence of states or transitions is undesirable.
        method states(--> Positional) {
            @!states;
        }

        #| Returns either an existing state with the specified name or a new one
        #| which will be added to the C<states> collection
        method get-state(Workflow:D: Str:D $state --> Tinky::State) {
            self.state($state) // do {
                my $new-state = Tinky::State.new(name => $state);
                self.states.append: $new-state;
                $new-state;
            }
        }

        #| This exception will be thrown if an attempt is made to define a transition which
        #| has the same 'from' and 'to' states as an existing one but with a differing name.
        #| Transitions must be unique by 'from' and 'to' state
        class X::Tinky::DuplicateTransition is Exception {
            has Str $.existing  is required;
            has Str $.duplicate is required;
            has Str $.from      is required;
            has Str $.to        is required;
            method message( --> Str ) {
                "Transition '{ $!duplicate }' duplicates '{ $!existing }' for '{ $!from }' => '{ $!to }'";
            }
        }

        #| Returns either an existing transition with the specified 'from' and 'to'
        #| states or creates a new one with 'name', 'from' and 'to'
        #| An exception will be thrown if an existing transition exists with a different
        #| name for the same 'from' and 'to' states
        method get-transition(Str $name, Str $from, Str $to --> Tinky::Transition) {
            my $from-state = self.get-state($from);
            my $to-state   = self.get-state($to);
            my $transition;
            if self.find-transition($from-state, $to-state) -> $t {
                if $t.name != $name {
                    X::Tinky::DuplicateTransition.new(existing => $t.name, duplicate => $name, :$from, :$to ).throw;
                }
                else {
                    $t;
                }
            }
            else {
                my $t = Tinky::Transition.new(:$name, from => $from-state, to => $to-state);
                self.transitions.append: $t;
                $t;
            }
        }

        #| Read/Write version of initial state
        has Tinky::State $.initial-state is rw;
    }

=begin pod

=head2 Workflow definition

These routines define the workflow.

=end pod

    #| This returns the workflow that is defined, all of the other routines must be
    #| called within the block passed to this one.
    sub workflow(Str $name, &declare-workflow --> Tinky::Declare::Workflow) is export {
        my $*TINKY-WORKFLOW = Workflow.new(name => $name);
        declare-workflow();

        # If the user forgot to define an initial-state then give them the first one
        if !$*TINKY-WORKFLOW.initial-state && $*TINKY-WORKFLOW.states.elems {
            $*TINKY-WORKFLOW.initial-state = $*TINKY-WORKFLOW.states[0];
        }

        $*TINKY-WORKFLOW;
    }

    #| This exception is thrown if any of the following routines are called
    #| outside of the block of "workflow" above.
    class X::Tinky::Declare::NoWorkflow is Exception {
        has Str $.what is required;
        method message(--> Str) {
            "{ $!what } can only be called within a 'workflow' block";
        }
    }

    #| Defines the initial state for objects that have the workflow
    #| applied if they do not already have a defined state.
    #| If this is not set for a given workflow then the first defined
    #| stated will be used instead.
    sub initial-state(Str $name --> Nil ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.initial-state = $*TINKY-WORKFLOW.get-state($name);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'initial-state').throw;
        }
    }

    #| This defines a routine that will be called whenever any state is
    #| entered by any object in the workflow.  The routine will be called
    #| with the Tinky::State object and the object that changed state.
    #| If you only want the "enters" for a specific State then it may be
    #| simpler to use "on-enter" defined in a "workflow-state" block.
    #| This can be called multiple times to add different handlers.
    sub on-enter-state( &on-enter-tap  --> Nil ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.enter-supply.tap(&on-enter-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-enter-state').throw;
        }
    }

    #| This defines a routine that will be called whenever any state is
    #| left by any object in the workflow.  The routine will be called
    #| with the Tinky::State object and the object that changed state.
    #| If you only want the "leaves" for a specific State then it may be
    #| simpler to use "on-leave" defined in a "workflow-state" block.
    #| This can be called multiple times to add different handlers.
    sub on-leave-state( &on-leave-tap  --> Nil ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.leave-supply.tap(&on-leave-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-leave-state').throw;
        }
    }

    #| This defines a routine that will be called when a "final" state is
    #| entered by any object in the workflow.  A final state is one for which
    #| there is no transition from the state to another one.
    #| The routine will be called with the Tinky::State object and the
    #| object that changed state.
    #| This can be called multiple times to add different handlers.
    sub on-final-state( &on-final-tap  --> Nil ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.final-supply.tap(&on-final-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-final-state').throw;
        }
    }

    #| This defines a routine that will be called whenever a new object
    #| has the workflow applied, it will be called with the object as an
    #| argument after the initial state has been applied.
    #| This can be called multiple times to add different handlers.
    sub on-apply( &on-applied-tap  --> Nil ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.applied-supply.tap(&on-applied-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-apply').throw;
        }
    }

    #| This defines a routine that will be called with a Tinky::Transition
    #| object and the object that is changing state whenever any object changes
    #| state.  This may be useful for logging for instance. If you want to
    #| act on the application of a particular transition then it may be more
    #| convenient to define a handler within a specific 'workflow-transition'.
    #| This can be used multiple times to add different handlers.
    sub on-transition( &on-transition-tap  --> Nil ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.transition-supply.tap(&on-transition-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-transition').throw;
        }
    }

    #| This defines a routine that is called before the workflow is applied to an
    #| object in order to check whether the application is valid, the routine
    #| must explicitly comply with the Tinky::ValidateCallback subset, that is to
    #| say it must explicity have a single 'Tinky::Object' argument and return a
    #| Bool.  The type of the argument can be a more specific type that does the
    #| Tinky::Object role which will only be called with objects of that type so
    #| you can define different validators for different types.
    sub validate-apply(Tinky::ValidateCallback $validate-apply --> Nil ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.validators.append: $validate-apply;
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'validate-apply').throw;
        }
    }

    proto workflow-state(|c) is export { * }

    #| This defines a Tinky::State with the specified name and without any
    #| specific behaviour. These can be specified in any order as whenever
    #| a state is referred to by name elsewhere it will be created in the
    #| workflow if it doesn't already exist.
    multi workflow-state(Str $name) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.get-state($name);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-state').throw;
        }
    }

    #| This defines a Tinky::State with the specified name and with the
    #| behaviours as defined defined in the block.
    multi workflow-state(Str $name, &declare-state) is export {
        if $*TINKY-WORKFLOW {
            my $*TINKY-STATE = $*TINKY-WORKFLOW.get-state($name);
            declare-state();
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-state').throw;
        }
    }

    #| This exception will be thrown if any of the following routines are
    #| used outside the 'workflow-state' block.
    class X::Tinky::Declare::NoState is Exception {
        has Str $.what is required;
        method message(--> Str) {
            "{ $!what } can only be called within a 'workflow-state' block";
        }
    }

    #| This defines a routine that will be called with the Tinky::Object
    #| whenever an object enters this state.  This can be used multiple
    #| times to define multiple handlers, however no guarantee is made
    #| as to the order in which they may be called, so some care may be
    #| required if you are altering the object at all.
    sub on-enter(&enter-tap ) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.enter-supply.tap(&enter-tap);
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'on-enter').throw;
        }
    }

    #| Define a validator for entry into the state.  As with the validate-apply
    #| for the workflow, this must have a specific signature that has a single
    #| positional parameter of a Tinky::Object (or a more specific type that
    #| does that role,) and returns a Bool. This can be specified multiple times
    #| with different more specific types and only those where the type of the
    #| object matches the signature will be called.  If any of the validators
    #| called returns False and exception will be thrown before the transition
    #| is applied.
    sub validate-enter(Tinky::ValidateCallback $validate-enter) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.enter-validators.append: $validate-enter;
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'validate-enter').throw;
        }
    }

    #| This defines a routine that will be called with the Tinky::Object
    #| whenever an object leaves this state.  This can be used multiple
    #| times to define multiple handlers, however no guarantee is made
    #| as to the order in which they may be called, so some care may be
    #| required if you are altering the object at all.
    sub on-leave(&leave-tap ) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.leave-supply.tap(&leave-tap);
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'on-leave').throw;
        }
    }

    #| Define a validator for leaving the state.  As with the validate-apply
    #| for the workflow, this must have a specific signature that has a single
    #| positional parameter of a Tinky::Object (or a more specific type that
    #| does that role,) and returns a Bool. This can be specified multiple times
    #| with different more specific types and only those where the type of the
    #| object matches the signature will be called.  If any of the validators
    #| called returns False and exception will be thrown before the transition
    #| is applied.
    sub validate-leave(Tinky::ValidateCallback $validate-leave) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.leave-validators.append: $validate-leave;
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'validate-leave').throw;
        }
    }

    proto workflow-transition(|c) { * }

    #| Define a Tinky::Transition between the two named states without any specific behavours.
    #| If the named states have not already been defined they will be created.
    #| The name of the transition does not need to be unique, the name of the transitions
    #| will be used to create methods on the Tinky::Object when the workflow is applied
    #| which determine which actual transition to apply by comparing the current state
    #| of the object with the 'from' state of the similarly named transitions.
    #| If there is a transition already defined with a different name but with the same
    #| 'from' and 'to' states then an exception will be thrown.
    multi sub workflow-transition(Str $name, Str $from, Str $to ) is export {
        if $*TINKY-WORKFLOW {
            my $*TINKY-TRANSITION = $*TINKY-WORKFLOW.get-transition($name, $from, $to);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-transition').throw;
        }
    }

    #| Define a Tinky::Transition between the two named states with the behaviour defined in the
    #| supplied block. The same constraints on naming and the 'from' and 'to' states as described
    #| above apply.
    multi sub workflow-transition(Str $name, Str $from, Str $to, &declare-transition ) is export {
        if $*TINKY-WORKFLOW {
            my $*TINKY-TRANSITION = $*TINKY-WORKFLOW.get-transition($name, $from, $to);
            declare-transition();
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-state').throw;
        }
    }

    #| This exception will be thrown if any of the following routines are called outside
    #| a 'workflow-transition' block.
    class X::Tinky::Declare::NoTransition is Exception {
        has Str $.what is required;
        method message(--> Str) {
            "{ $!what } can only be called within a 'workflow-transition' block";
        }
    }

    #| This defines a tap on the transition's supply which will have the Tinky::Object
    #| which has changed its state emitted after the transition has been fully applied.
    #| This can be used multiple times, but altering the object should be handled with
    #| care as no guarantee is made as to the order the handlers will be executed.
    sub on-apply-transition(&apply-transition) is export {
        if $*TINKY-TRANSITION {
            $*TINKY-TRANSITION.supply.tap(&apply-transition);
        }
        else {
            X::Tinky::Declare::NoTransition.new(what => 'on-apply-transition').throw;
        }
    }

    #| Define a validator for the application of the transition.  As with the validate-apply
    #| for the workflow, this must have a specific signature that has a single
    #| positional parameter of a Tinky::Object (or a more specific type that
    #| does that role,) and returns a Bool. This can be specified multiple times
    #| with different more specific types and only those where the type of the
    #| object matches the signature will be called.  If any of the validators
    #| called returns False and exception will be thrown before the transition
    #| is applied.
    sub validate-apply-transition(Tinky::ValidateCallback $validate-apply) is export {
        if $*TINKY-TRANSITION {
            $*TINKY-TRANSITION.validators.append: $validate-apply;
        }
        else {
            X::Tinky::Declare::NoTransition.new(what => 'validate-apply-transition').throw;
        }

    }
}

# vim: expandtab shiftwidth=4 ft=raku
