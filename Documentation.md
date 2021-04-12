NAME
====

Tinky::Declare - Declarative creation of Tinky machines

SYNOPSIS
========

This is the functional equivalent to the [Tinky synopsis](https://github.com/jonathanstowe/Tinky/blob/master/README.md#synopsis):

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

DESCRIPTION
===========

This provides a declarative interface to create [Tinky](https://github.com/jonathanstowe/Tinky) 'workflow' objects. You probably want to familiarise yourself with the [Tinky documentation](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md) to get an idea of what is going on under the hood.

Essentially it creates a small DSL that allows you to create a [Tinky::Workflow](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkyworkflow) populated with the [State](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkystate) and [Transition](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#class-tinkystate) objects that describe the workflow. Because the underlying objects are created for you only those features of Tinky that don't require sub-classing are exposed, such as tapping the supplies for leaving and entering a state (or all states,) the application of a transition (or all transitions,) and application of the workflow to an object, as well as [validation callbacks](https://github.com/jonathanstowe/Tinky/blob/master/Documentation.md#subset-validatecallback) for all of those events.

class Tinky::Declare::Workflow
------------------------------

This is a sub-class of Tinky::Workflow that provides some extra functionality that is required to create and find the states and transitions by name.

### method state

```raku
method state(
    Str:D $state
) returns Tinky::State
```

Gets the named state or undefined type object

### method states

```raku
method states() returns Positional
```

This over-rides the Tinky::Workflow because the states will be populated as they are seen. The behaviour of the base version in the absence of states or transitions is undesirable.

### method get-state

```raku
method get-state(
    Str:D $state
) returns Tinky::State
```

Returns either an existing state with the specified name or a new one which will be added to the C<states> collection

class Tinky::Declare::Workflow::X::Tinky::DuplicateTransition
-------------------------------------------------------------

This exception will be thrown if an attempt is made to define a transition which has the same 'from' and 'to' states as an existing one but with a differing name. Transitions must be unique by 'from' and 'to' state

### method get-transition

```raku
method get-transition(
    Str $name,
    Str $from,
    Str $to
) returns Tinky::Transition
```

Returns either an existing transition with the specified 'from' and 'to' states or creates a new one with 'name', 'from' and 'to' An exception will be thrown if an existing transition exists with a different name for the same 'from' and 'to' states

### has Tinky::State $.initial-state

Read/Write version of initial state

Workflow definition
-------------------

These routines define the workflow.

### sub workflow

```raku
sub workflow(
    Str $name,
    &declare-workflow
) returns Tinky::Declare::Workflow
```

This returns the workflow that is defined, all of the other routines must be called within the block passed to this one.

class Tinky::Declare::X::Tinky::Declare::NoWorkflow
---------------------------------------------------

This exception is thrown if any of the following routines are called outside of the block of "workflow" above.

### sub initial-state

```raku
sub initial-state(
    Str $name
) returns Nil
```

Defines the initial state for objects that have the workflow applied if they do not already have a defined state. If this is not set for a given workflow then the first defined stated will be used instead.

### sub on-enter-state

```raku
sub on-enter-state(
    &on-enter-tap
) returns Nil
```

This defines a routine that will be called whenever any state is entered by any object in the workflow. The routine will be called with the Tinky::State object and the object that changed state. If you only want the "enters" for a specific State then it may be simpler to use "on-enter" defined in a "workflow-state" block. This can be called multiple times to add different handlers.

### sub on-leave-state

```raku
sub on-leave-state(
    &on-leave-tap
) returns Nil
```

This defines a routine that will be called whenever any state is left by any object in the workflow. The routine will be called with the Tinky::State object and the object that changed state. If you only want the "leaves" for a specific State then it may be simpler to use "on-leave" defined in a "workflow-state" block. This can be called multiple times to add different handlers.

### sub on-final-state

```raku
sub on-final-state(
    &on-final-tap
) returns Nil
```

This defines a routine that will be called when a "final" state is entered by any object in the workflow. A final state is one for which there is no transition from the state to another one. The routine will be called with the Tinky::State object and the object that changed state. This can be called multiple times to add different handlers.

### sub on-apply

```raku
sub on-apply(
    &on-applied-tap
) returns Nil
```

This defines a routine that will be called whenever a new object has the workflow applied, it will be called with the object as an argument after the initial state has been applied. This can be called multiple times to add different handlers.

### sub on-transition

```raku
sub on-transition(
    &on-transition-tap
) returns Nil
```

This defines a routine that will be called with a Tinky::Transition object and the object that is changing state whenever any object changes state. This may be useful for logging for instance. If you want to act on the application of a particular transition then it may be more convenient to define a handler within a specific 'workflow-transition'. This can be used multiple times to add different handlers.

### sub validate-apply

```raku
sub validate-apply(
    Callable $validate-apply where { ... }
) returns Nil
```

This defines a routine that is called before the workflow is applied to an object in order to check whether the application is valid, the routine must explicitly comply with the Tinky::ValidateCallback subset, that is to say it must explicity have a single 'Tinky::Object' argument and return a Bool. The type of the argument can be a more specific type that does the Tinky::Object role which will only be called with objects of that type so you can define different validators for different types.

### multi sub workflow-state

```raku
multi sub workflow-state(
    Str $name
) returns Mu
```

This defines a Tinky::State with the specified name and without any specific behaviour. These can be specified in any order as whenever a state is referred to by name elsewhere it will be created in the workflow if it doesn't already exist.

### multi sub workflow-state

```raku
multi sub workflow-state(
    Str $name,
    &declare-state
) returns Mu
```

This defines a Tinky::State with the specified name and with the behaviours as defined defined in the block.

class Tinky::Declare::X::Tinky::Declare::NoState
------------------------------------------------

This exception will be thrown if any of the following routines are used outside the 'workflow-state' block.

### sub on-enter

```raku
sub on-enter(
    &enter-tap
) returns Mu
```

This defines a routine that will be called with the Tinky::Object whenever an object enters this state. This can be used multiple times to define multiple handlers, however no guarantee is made as to the order in which they may be called, so some care may be required if you are altering the object at all.

### sub validate-enter

```raku
sub validate-enter(
    Callable $validate-enter where { ... }
) returns Mu
```

Define a validator for entry into the state. As with the validate-apply for the workflow, this must have a specific signature that has a single positional parameter of a Tinky::Object (or a more specific type that does that role,) and returns a Bool. This can be specified multiple times with different more specific types and only those where the type of the object matches the signature will be called. If any of the validators called returns False and exception will be thrown before the transition is applied.

### sub on-leave

```raku
sub on-leave(
    &leave-tap
) returns Mu
```

This defines a routine that will be called with the Tinky::Object whenever an object leaves this state. This can be used multiple times to define multiple handlers, however no guarantee is made as to the order in which they may be called, so some care may be required if you are altering the object at all.

### sub validate-leave

```raku
sub validate-leave(
    Callable $validate-leave where { ... }
) returns Mu
```

Define a validator for leaving the state. As with the validate-apply for the workflow, this must have a specific signature that has a single positional parameter of a Tinky::Object (or a more specific type that does that role,) and returns a Bool. This can be specified multiple times with different more specific types and only those where the type of the object matches the signature will be called. If any of the validators called returns False and exception will be thrown before the transition is applied.

### multi sub workflow-transition

```raku
multi sub workflow-transition(
    Str $name,
    Str $from,
    Str $to
) returns Mu
```

Define a Tinky::Transition between the two named states without any specific behavours. If the named states have not already been defined they will be created. The name of the transition does not need to be unique, the name of the transitions will be used to create methods on the Tinky::Object when the workflow is applied which determine which actual transition to apply by comparing the current state of the object with the 'from' state of the similarly named transitions. If there is a transition already defined with a different name but with the same 'from' and 'to' states then an exception will be thrown.

### multi sub workflow-transition

```raku
multi sub workflow-transition(
    Str $name,
    Str $from,
    Str $to,
    &declare-transition
) returns Mu
```

Define a Tinky::Transition between the two named states with the behaviour defined in the supplied block. The same constraints on naming and the 'from' and 'to' states as described above apply.

class Tinky::Declare::X::Tinky::Declare::NoTransition
-----------------------------------------------------

This exception will be thrown if any of the following routines are called outside a 'workflow-transition' block.

### sub on-apply-transition

```raku
sub on-apply-transition(
    &apply-transition
) returns Mu
```

This defines a tap on the transition's supply which will have the Tinky::Object which has changed its state emitted after the transition has been fully applied. This can be used multiple times, but altering the object should be handled with care as no guarantee is made as to the order the handlers will be executed.

### sub validate-apply-transition

```raku
sub validate-apply-transition(
    Callable $validate-apply where { ... }
) returns Mu
```

Define a validator for the application of the transition. As with the validate-apply for the workflow, this must have a specific signature that has a single positional parameter of a Tinky::Object (or a more specific type that does that role,) and returns a Bool. This can be specified multiple times with different more specific types and only those where the type of the object matches the signature will be called. If any of the validators called returns False and exception will be thrown before the transition is applied.

