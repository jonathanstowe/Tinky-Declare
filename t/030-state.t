#!/usr/bin/env raku

use Test;
use Tinky;
use Tinky::Declare;

subtest {
    my $workflow = workflow 'test-workflow', {
        workflow-state 'one';
        workflow-state 'one';
    }

    is $workflow.states.elems, 1, "only got one state despite declaring it twice";
    ok $workflow.states.grep(*.name eq 'one'), "and we got the state we expected";
}, 'declare state';

subtest {
    my class TestClass does Tinky::Object {
    }

    my $object = TestClass.new;

    my $leave-channel = Channel.new;
    my $enter-channel = Channel.new;

    my $workflow = workflow 'test-workflow', {
        workflow-state 'first', {
            on-leave -> $object {
                $leave-channel.send: $object;
                $leave-channel.close;
            }
        }
        workflow-state 'second', {
            on-enter -> $object {
                $enter-channel.send: $object;
                $enter-channel.close;
            }
        }

        initial-state 'first';

        workflow-transition 'test-transition', 'first', 'second';
    }

    $object.apply-workflow($workflow);

    $object.test-transition;

    my @enters = $enter-channel.list;
    is @enters.elems, 1, 'got one leave';
    for @enters -> $enter {
        isa-ok $enter, TestClass;
        is $enter.WHICH, $object.WHICH, 'got the same object';
    }
    my @leaves = $leave-channel.list;
    is @leaves.elems, 1, 'got one leave';
    for @leaves -> $leave {
        isa-ok $leave, TestClass;
        is $leave.WHICH, $object.WHICH, 'got the same object';
    }


}, 'enter/leave state';

subtest {
    my class AllowLeave does Tinky::Object { }
    my $allow-leave = AllowLeave.new;
    my class NoLeave    does Tinky::Object { }
    my $no-leave    = NoLeave.new;

    my $workflow = workflow 'test-leave-workflow', {
        initial-state 'leave-first';
        workflow-state 'leave-first', {
            validate-leave -> AllowLeave $ --> Bool {
                True;
            }
            validate-leave -> NoLeave $ --> Bool {
                False;
            }
        }
        workflow-state 'leave-second';
        workflow-transition 'test-leave-transition', 'leave-first', 'leave-second';
    };

    $allow-leave.apply-workflow($workflow);
    $no-leave.apply-workflow($workflow);
    lives-ok { $allow-leave.test-leave-transition }, 'allowed transition';
    is $allow-leave.state.name, 'leave-second', 'and the object is in new state';
    throws-like { $no-leave.test-leave-transition }, Tinky::X::TransitionRejected, "and this one isn't";

}, 'validate leave';

subtest {
    class AllowEnter does Tinky::Object { }
    my $allow-enter = AllowEnter.new;
    class NoEnter    does Tinky::Object { }
    my $no-enter    = NoEnter.new;

    my $workflow = workflow 'test-enter-workflow', {
        initial-state 'enter-first';
        workflow-state 'enter-first';
        workflow-state 'enter-second', {
            validate-enter -> AllowEnter $ --> Bool {
                True;
            }
            validate-enter -> NoEnter $ --> Bool {
                False;
            }
        }
        workflow-transition 'test-enter-transition', 'enter-first', 'enter-second';
    };

    $allow-enter.apply-workflow($workflow);
    $no-enter.apply-workflow($workflow);
    lives-ok { $allow-enter.test-enter-transition }, 'allowed transition';
    is $allow-enter.state.name, 'enter-second', 'and the object is in new state';
    throws-like { $no-enter.test-enter-transition }, Tinky::X::TransitionRejected, "and this one isn't";

}, 'validate leave';

done-testing();
# vim: ft=raku
