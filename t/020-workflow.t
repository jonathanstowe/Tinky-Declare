#!/usr/bin/env raku

use Test;
use Tinky::Declare;
use Tinky;

subtest {
    my $name = 'test-workflow';
    my $workflow = workflow $name, -> {

    };

    isa-ok $workflow, 'Tinky::Workflow';
    isa-ok $workflow, 'Tinky::Declare::Workflow';
    is $workflow.name, $name, 'workflow has correct name';
    is $workflow.transitions.elems, 0, 'no transitions';
    is $workflow.states.elems ,0, 'no states defined';
    ok my $state = $workflow.get-state('first'), 'get-state';
    is $state.name, 'first', 'created state has the expected name';
    is $workflow.states.elems ,1, 'and there is one state on the workflow';
    ok $state = $workflow.get-state('first'), 'get-state again';
    is $workflow.states.elems ,1, 'and there is still one state on the workflow';


}, 'workflow - nothing in body';

subtest {
    my $name = 'test-workflow';
    my $workflow = workflow $name, {
        workflow-state 'first';
        workflow-state 'second';

    };

    isa-ok $workflow, 'Tinky::Workflow';
    isa-ok $workflow, 'Tinky::Declare::Workflow';
    is $workflow.name, $name, 'workflow has correct name';
    is $workflow.transitions.elems, 0, 'no transitions';
    is $workflow.states.elems , 2, 'two states';
}, 'workflow - only states defined in body';

subtest {
    my $name = 'test-workflow';
    my $workflow = workflow $name, {
        workflow-state 'first';
        workflow-state 'second';
        initial-state 'first';

    };

    isa-ok $workflow, 'Tinky::Workflow';
    isa-ok $workflow, 'Tinky::Declare::Workflow';
    is $workflow.name, $name, 'workflow has correct name';
    is $workflow.transitions.elems, 0, 'no transitions';
    is $workflow.states.elems , 2, 'two states';
    is $workflow.initial-state.name, 'first', 'initial-state is as expected';
}, 'workflow - states and initial-state defined in body';

subtest {
    my $name = 'test-workflow';

    class GoodOne does Tinky::Object { }
    class BadOne  does Tinky::Object { }

    my $channel = Channel.new;

    my $workflow = workflow $name, {
        initial-state 'first';

        validate-apply -> GoodOne $ --> Bool {
            True;
        }
        validate-apply -> BadOne $ --> Bool {
            False;
        }
        on-apply -> $object {
            $channel.send: $object;
            $channel.close;
        }
    };

    my $good-one = GoodOne.new;
    my $bad-one  = BadOne.new;

    isa-ok $workflow, 'Tinky::Workflow';
    isa-ok $workflow, 'Tinky::Declare::Workflow';
    is $workflow.name, $name, 'workflow has correct name';

    lives-ok { $good-one.apply-workflow($workflow) }, 'good apply';

    my @applied = $channel.list;

    is @applied.elems, 1, "applied supply has event";
    ok @applied[0] ~~ GoodOne, "and it is the object";
    is $good-one.state.name, 'first', "and the object has the correct state";
    throws-like { $bad-one.apply-workflow($workflow) }, Tinky::X::ObjectRejected, "Bad one rejected";
}, 'workflow - validate-apply';

subtest {
    my $name = 'test-workflow';
    class TestClass does Tinky::Object {
        has Str $.name;
    }
    my $object = TestClass.new(name => 'test-object');
    my $enter-channel       = Channel.new;
    my $leave-channel       = Channel.new;
    my $final-channel       = Channel.new;
    my $transition-channel  = Channel.new;

    my $workflow = workflow $name , {
        initial-state 'first';
        workflow-transition 'test-transition', 'first', 'second';
        on-enter-state -> ( $state, $object ) {
            $enter-channel.send: [ $state, $object ];
            $enter-channel.close;
        }
        on-leave-state -> ( $state, $object ) {
            $leave-channel.send: [ $state, $object ];
            $leave-channel.close;
        }
        on-final-state -> ( $state, $object ) {
            $final-channel.send: [ $state, $object ];
            $final-channel.close;
        }
        on-transition -> ( $transition, $object ) {
            $transition-channel.send: [ $transition, $object ];
            $transition-channel.close;
        }
    };
    $object.apply-workflow($workflow);
    $object.test-transition;
    is $object.state.name, 'second', 'object is in the right state';
    my @enters = $enter-channel.list;
    is @enters.elems, 1, "got one entered event";
    for @enters -> ( $state, $object ) {
        isa-ok $state, Tinky::State;
        is $state.name, 'second', 'got the right entered state';
        is $object.name, 'test-object', 'got the right object';
    }

    my @finals = $final-channel.list;
    is @finals.elems, 1, "got one final event";
    for @finals -> ( $state, $object ) {
        isa-ok $state, Tinky::State;
        is $state.name, 'second', 'got the right final state';
        is $object.name, 'test-object', 'got the right object';
    }

    my @leaves = $leave-channel.list;
    is @leaves.elems, 1, "got one leave event";
    for @leaves -> ( $state, $object ) {
        isa-ok $state, Tinky::State;
        is $state.name, 'first', 'got the right left state';
        is $object.name, 'test-object', 'got the right object';
    }

    my @transitions = $transition-channel.list;
    is @transitions.elems, 1, "got one transition event";
    for @transitions -> ( $transition, $object ) {
        isa-ok $transition, Tinky::Transition;
        is $transition.name, 'test-transition', 'got the right left state';
        is $object.name, 'test-object', 'got the right object';
    }

}, "test workflow level supplies";

subtest {
    my class TestClass does Tinky::Object { }

    my $workflow = workflow 'test-initial', {
        workflow-state 'one';
        workflow-state 'two';
    };

    is $workflow.initial-state.name, 'one', 'got the expected initial-state';
    my $object = TestClass.new;
    $object.apply-workflow($workflow);
    is $object.state.name, 'one', 'and a new object in the workflow has the right state';

}, 'default the initial state';

done-testing;
# vim: ft=raku
