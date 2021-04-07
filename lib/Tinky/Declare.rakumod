use v6;

module Tinky::Declare {
    use Tinky;

    class Workflow is Tinky::Workflow {
        #| Gets the named state or undefined type object
        method state(Str:D $state --> Tinky::State) {
            self.states.first({ $_ ~~ $state }) // Tinky::State;
        }

        has Tinky::State @.states;

        # Over-ride the Tinky::Workflow because we don't want the
        # throwing behaviour
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

    sub workflow(Str $name, &declare-workflow --> Tinky::Workflow) is export {
        my $*TINKY-WORKFLOW = Workflow.new(name => $name);
        declare-workflow();

        # If the user forgot to define an initial-state then give them the first one
        if !$*TINKY-WORKFLOW.initial-state && $*TINKY-WORKFLOW.states.elems {
            $*TINKY-WORKFLOW.initial-state = $*TINKY-WORKFLOW.states[0];
        }

        $*TINKY-WORKFLOW;
    }

    class X::Tinky::Declare::NoWorkflow is Exception {
        has Str $.what is required;
        method message(--> Str) {
            "{ $!what } can only be called within a 'workflow' block";
        }
    }

    sub initial-state(Str $name) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.initial-state = $*TINKY-WORKFLOW.get-state($name);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'initial-state').throw;
        }
    }

    sub on-enter-state( &on-enter-tap ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.enter-supply.tap(&on-enter-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-enter-state').throw;
        }
    }

    sub on-leave-state( &on-leave-tap ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.leave-supply.tap(&on-leave-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-leave-state').throw;
        }
    }

    sub on-final-state( &on-final-tap ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.final-supply.tap(&on-final-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-final-state').throw;
        }
    }

    sub on-apply( &on-applied-tap ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.applied-supply.tap(&on-applied-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-apply').throw;
        }
    }

    sub on-transition( &on-transition-tap ) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.transition-supply.tap(&on-transition-tap);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'on-transition').throw;
        }
    }

    sub validate-apply(Tinky::ValidateCallback $validate-apply) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.validators.append: $validate-apply;
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'validate-apply').throw;
        }
    }

    proto workflow-state(|c) is export { * }

    multi workflow-state(Str $name) is export {
        if $*TINKY-WORKFLOW {
            $*TINKY-WORKFLOW.get-state($name);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-state').throw;
        }
    }

    multi workflow-state(Str $name, &declare-state) is export {
        if $*TINKY-WORKFLOW {
            my $*TINKY-STATE = $*TINKY-WORKFLOW.get-state($name);
            declare-state();
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-state').throw;
        }
    }

    class X::Tinky::Declare::NoState is Exception {
        has Str $.what is required;
        method message(--> Str) {
            "{ $!what } can only be called within a 'workflow-state' block";
        }
    }

    sub on-enter(&enter-tap ) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.enter-supply.tap(&enter-tap);
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'on-enter').throw;
        }
    }

    sub validate-enter(Tinky::ValidateCallback $validate-enter) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.enter-validators.append: $validate-enter;
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'validate-enter').throw;
        }
    }

    sub on-leave(&leave-tap ) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.leave-supply.tap(&leave-tap);
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'on-leave').throw;
        }
    }

    sub validate-leave(Tinky::ValidateCallback $validate-leave) is export {
        if $*TINKY-STATE {
            $*TINKY-STATE.leave-validators.append: $validate-leave;
        }
        else {
            X::Tinky::Declare::NoState.new(what => 'validate-leave').throw;
        }
    }

    proto workflow-transition(|c) { * }

    multi sub workflow-transition(Str $name, Str $from, Str $to ) is export {
        if $*TINKY-WORKFLOW {
            my $*TINKY-TRANSITION = $*TINKY-WORKFLOW.get-transition($name, $from, $to);
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-transition').throw;
        }
    }

    multi sub workflow-transition(Str $name, Str $from, Str $to, &declare-transition ) is export {
        if $*TINKY-WORKFLOW {
            my $*TINKY-TRANSITION = $*TINKY-WORKFLOW.get-transition($name, $from, $to);
            declare-transition();
        }
        else {
            X::Tinky::Declare::NoWorkflow.new(what => 'workflow-state').throw;
        }
    }

    class X::Tinky::Declare::NoTransition is Exception {
        has Str $.what is required;
        method message(--> Str) {
            "{ $!what } can only be called within a 'workflow-transition' block";
        }
    }

    sub on-apply-transition(&apply-transition) is export {
        if $*TINKY-TRANSITION {
            $*TINKY-TRANSITION.supply.tap(&apply-transition);
        }
        else {
            X::Tinky::Declare::NoTransition.new(what => 'on-apply-transition').throw;
        }
    }

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
