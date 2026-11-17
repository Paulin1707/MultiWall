-- Index foreign-key columns used when looking up signaling participants.
-- These support cleanup and peer-message lookups as sessions grow.
create index if not exists idx_signaling_sender_participant
  on public.signaling_messages (sender_participant_id);

create index if not exists idx_signaling_recipient_participant
  on public.signaling_messages (recipient_participant_id);
