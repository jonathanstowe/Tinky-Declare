# Tinky::Declare

Declarative creation of Tinky machines

![Build Status](https://github.com/jonathanstowe/Tinky-Declare/workflows/CI/badge.svg)

## Synopsis

This is the functional equivalent to the [Tinky synopsis](https://github.com/jonathanstowe/Tinky/blob/master/README.md#synopsis):

```raku
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
```

There are further [examples in the distribution](examples).

## Description

This provides a declarative interface to create [Tinky](https://github.com/jonathanstowe/Tinky) 'workflow' objects.
You probably want to familiarise yourself with the [Tinky documentation](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md)
to get an idea of what is going on under the hood.

Essentially it creates a small DSL that allows you to create a [Tinky::Workflow](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkyworkflow)
populated with the [State](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkystate) and [Transition](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkystate)
objects that describe the workflow.  Because the underlying objects are created for you only those features of Tinky that don't require
sub-classing are exposed, such as tapping the supplies for leaving and entering a state (or all states,) the application of a transition (or all transitions,)
and application of the workflow to an object, as well as [validation callbacks](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#subset-validatecallback)
for all of those events.

The full documentation is [in the distribution](Documentation.md).

## Installation

## Support

## Licence & Copyright

This is free software.

Please see [LICENCE](LICENCE) for the details.

© Jonathan Stowe 2021
