#!/usr/bin/env raku

use Test;
use Tinky::Declare;
use Tinky;

subtest {
    my $workflow = workflow 'test-workflow', {
        workflow-transition 'test-transition', 'new', 'done';
    }

    is $workflow.states.elems, 2, "have two states";
    is $workflow.states.grep({ .name ~~ 'new'|'done' }).elems, 2, 'and they are the right ones';
    is $workflow.transitions.elems, 1, 'have one transition';
    my $transition = $workflow.transitions[0];
    isa-ok $transition, Tinky::Transition;
    is $transition.from.name, 'new', 'got the right "from" state';
    is $transition.to.name, 'done', 'got the right "to" state';

}, 'check transition creation';

subtest {
    my $channel = Channel.new;
    my $workflow = workflow 'test-workflow', {
        initial-state 'new';
        workflow-transition 'test-transition', 'new', 'done', {
            on-apply-transition -> $object {
                $channel.send: $object;
                $channel.close;
            }
        }
    }

    my class TestClass does Tinky::Object { }

    my $object = TestClass.new;
    $object.apply-workflow($workflow);

    $object.test-transition;
    is $object.state.name, 'done', 'the state has changed';
    my @applies = $channel.list;
    is @applies.elems, 1, 'got one transition on supply';
    isa-ok @applies[0], TestClass, 'and the thing is the right thing';
}, 'check supply';

subtest {
    my class GoodOne does Tinky::Object {}
    my class BadOne  does Tinky::Object {}

    my $channel = Channel.new;
    my $workflow = workflow 'test-workflow', {
        initial-state 'new';
        workflow-transition 'test-apply-transition', 'new', 'done', {
            validate-apply-transition -> GoodOne --> Bool {
                True;
            }
            validate-apply-transition -> BadOne --> Bool {
                False;
            }
        }
    }

    my $good = GoodOne.new;
    $good.apply-workflow($workflow);
    my $bad  = BadOne.new;
    $bad.apply-workflow($workflow);

    lives-ok { $good.test-apply-transition }, 'apply transition with good class';
    is $good.state.name, 'done', 'and the state is correct';
    throws-like { $bad.test-apply-transition }, Tinky::X::TransitionRejected, 'bad class is rejected';
    is $bad.state.name, 'new', "and the state isn't changed";

}, "validate apply";

done-testing();
# vim: ft=raku
