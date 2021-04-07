#!/usr/bin/env raku

use Tinky;
use Tinky::Declare;
use Test;

lives-ok {
    class Ticket does Tinky::Object {
        has Str $.ticket-number = (^100000).pick.fmt("%08d");
        has Str $.owner;
    }

    my $transition-channel = Channel.new;

    my Bool $rejected = False;
    my Bool $stall    = False;
    my Bool $final    = False;
    my $workflow = workflow 'ticket-workflow', {
        initial-state 'new';
        workflow-state 'new';
        workflow-state 'open';
        workflow-transition 'open', 'new', 'open';

        workflow-state 'rejected' , {
            on-enter -> $object {
                $rejected = True;
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
                $stall = True;
            }
        }

        workflow-state 'completed';

        workflow-transition 'unstall', 'stalled', 'in-progress';
        workflow-transition 'take', 'open', 'in-progress';
        workflow-transition 'complete', 'open', 'complete';
        workflow-transition 'complete', 'in-progress', 'complete';

        on-transition -> ( $transition, $object ) {
            $transition-channel.send: [ $transition.from.name, $transition.to.name ];
        }

        on-final-state -> ( $state, $object) {
            $final = True;
        }

    };

    my $ticket-a = Ticket.new(owner => "Operator A");

    $ticket-a.apply-workflow($workflow);

    $ticket-a.open;

    $ticket-a.take;

    is-deeply $ticket-a.next-states>>.name, [ 'stalled', 'complete'], 'next-states is right';

    $ticket-a.state = $workflow.state('stalled');

    $ticket-a.reject;

    $transition-channel.close;
    my @transitions = $transition-channel.list;
    is-deeply @transitions, [
        ['new','open'],
        ['open','in-progress'],
        ['in-progress','stalled'],
        ['stalled','rejected']
    ],'got the right transitions';
    ok $rejected, 'saw rejected';
    ok $stall, 'saw stall';
    ok $final, 'saw final';
}, 'synopsis code runs ok';

done-testing();
# vim: ft=raku
