/**
 * Trigger on AI_Case_Event__e Platform Event
 * Delegates to AICaseEventSubscriber handler class
 * Follows one-trigger-per-object pattern
 */
trigger AICaseEventTrigger on AI_Case_Event__e (after insert) {
    AICaseEventSubscriber.handleEvents(Trigger.new);
}
