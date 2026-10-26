/**
 * @file Queue Action Request Validator
 * Purpose: Validates queue transition requests such as call-next, transfer, and no-show marking.
 * SRS Requirements: FR-2.1 (Queue Action Validation), BR-2 (State Transitions)
 */

function validateQueueAction(body = {}) {
  const { queueEntryId, action } = body;
  const allowedActions = ['call', 'start', 'complete', 'no_show', 'transfer'];

  if (!queueEntryId || typeof queueEntryId !== 'string') {
    return { error: new Error('queueEntryId is required') };
  }
  if (!action || !allowedActions.includes(action)) {
    return { error: new Error(`action must be one of: ${allowedActions.join(', ')}`) };
  }
  return { value: body };
}

module.exports = { validateQueueAction };
