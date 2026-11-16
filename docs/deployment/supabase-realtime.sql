-- Run in the Supabase SQL Editor for the same project as SUPABASE_URL.
begin;

drop policy if exists metagym_receive_own_broadcast on realtime.messages;
create policy metagym_receive_own_broadcast on realtime.messages
  for select to authenticated
  using (
    auth.jwt() ->> 'metagym_realtime' = 'true'
    and extension = 'broadcast'
    and realtime.topic() = 'metagym-user:' || (select auth.uid())::text
  );

drop policy if exists metagym_restrict_broadcast_topics on realtime.messages;
create policy metagym_restrict_broadcast_topics on realtime.messages
  as restrictive for select to authenticated
  using (
    (auth.jwt() ->> 'metagym_realtime') is distinct from 'true'
    or (
      extension = 'broadcast'
      and realtime.topic() = 'metagym-user:' || (select auth.uid())::text
    )
  );

drop policy if exists metagym_deny_client_broadcast on realtime.messages;
create policy metagym_deny_client_broadcast on realtime.messages
  as restrictive for insert to authenticated
  with check ((auth.jwt() ->> 'metagym_realtime') is distinct from 'true');

commit;
