CREATE TABLE "public"."canvas_strokes" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "space_id"   uuid                     NOT NULL,
  "user_id"    uuid                     NOT NULL,
  "stroke"     jsonb                    NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "canvas_strokes_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."canvas_strokes"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."chat_messages" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "space_id"   uuid                     NOT NULL,
  "user_id"    uuid                     NOT NULL,
  "body"       text                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "chat_messages_body_check" CHECK (((char_length(body) >= 1) AND (char_length(body) <= 4000))),
  CONSTRAINT "chat_messages_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."chat_messages"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."paper_pages" (
  "space_id"   uuid                     NOT NULL,
  "content"    text                     NOT NULL DEFAULT ''::text,
  "updated_by" uuid,
  "updated_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "paper_pages_pkey" PRIMARY KEY (space_id)
);

ALTER TABLE "public"."paper_pages"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."relationship_spaces" (
  "id"         uuid                     NOT NULL DEFAULT gen_random_uuid(),
  "name"       text                     NOT NULL DEFAULT 'Our shared space'::text,
  "created_by" uuid                     NOT NULL,
  "created_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "relationship_spaces_pkey" PRIMARY KEY (id)
);

ALTER TABLE "public"."relationship_spaces"
  ENABLE ROW LEVEL SECURITY;

CREATE TABLE "public"."space_members" (
  "space_id"  uuid                     NOT NULL,
  "user_id"   uuid                     NOT NULL,
  "joined_at" timestamp with time zone NOT NULL DEFAULT now(),
  CONSTRAINT "space_members_pkey" PRIMARY KEY (space_id, user_id)
);

ALTER TABLE "public"."space_members"
  ENABLE ROW LEVEL SECURITY;

ALTER TABLE "public"."canvas_strokes"
  ADD CONSTRAINT "canvas_strokes_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id);

ALTER TABLE "public"."chat_messages"
  ADD CONSTRAINT "chat_messages_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id);

ALTER TABLE "public"."paper_pages"
  ADD CONSTRAINT "paper_pages_updated_by_fkey" FOREIGN KEY (updated_by) REFERENCES auth.users(id);

ALTER TABLE "public"."relationship_spaces"
  ADD CONSTRAINT "relationship_spaces_created_by_fkey" FOREIGN KEY (created_by) REFERENCES auth.users(id);

ALTER TABLE "public"."canvas_strokes"
  ADD CONSTRAINT "canvas_strokes_space_id_fkey" FOREIGN KEY (space_id) REFERENCES public.relationship_spaces(id) ON DELETE CASCADE;

ALTER TABLE "public"."chat_messages"
  ADD CONSTRAINT "chat_messages_space_id_fkey" FOREIGN KEY (space_id) REFERENCES public.relationship_spaces(id) ON DELETE CASCADE;

ALTER TABLE "public"."paper_pages"
  ADD CONSTRAINT "paper_pages_space_id_fkey" FOREIGN KEY (space_id) REFERENCES public.relationship_spaces(id) ON DELETE CASCADE;

ALTER TABLE "public"."space_members"
  ADD CONSTRAINT "space_members_space_id_fkey" FOREIGN KEY (space_id) REFERENCES public.relationship_spaces(id) ON DELETE CASCADE;

ALTER TABLE "public"."space_members"
  ADD CONSTRAINT "space_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;

CREATE POLICY "Members create strokes" ON "public"."canvas_strokes"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = canvas_strokes.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "Members read strokes" ON "public"."canvas_strokes"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = canvas_strokes.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "Members read messages" ON "public"."chat_messages"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = chat_messages.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "Members send messages" ON "public"."chat_messages"
  FOR INSERT
  TO "authenticated"
  WITH CHECK (((user_id = ( SELECT auth.uid() AS uid)) AND (EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = chat_messages.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid)))))));

CREATE POLICY "Members create paper" ON "public"."paper_pages"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = paper_pages.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "Members read paper" ON "public"."paper_pages"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = paper_pages.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "Members update paper" ON "public"."paper_pages"
  FOR UPDATE
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = paper_pages.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid))))))
  WITH CHECK ((EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = paper_pages.space_id) AND (m.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "Create own space" ON "public"."relationship_spaces"
  FOR INSERT
  TO "authenticated"
  WITH CHECK ((created_by = ( SELECT auth.uid() AS uid)));

CREATE POLICY "Members read spaces" ON "public"."relationship_spaces"
  FOR SELECT
  TO "authenticated"
  USING ((EXISTS ( SELECT 1
   FROM public.space_members m
  WHERE ((m.space_id = relationship_spaces.id) AND (m.user_id = ( SELECT auth.uid() AS uid))))));

CREATE POLICY "Read own memberships" ON "public"."space_members"
  FOR SELECT
  TO "authenticated"
  USING ((user_id = ( SELECT auth.uid() AS uid)));

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."canvas_strokes";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."chat_messages";

ALTER PUBLICATION "supabase_realtime" ADD TABLE "public"."paper_pages";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."canvas_strokes" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."canvas_strokes" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."canvas_strokes" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."canvas_strokes" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."chat_messages" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."chat_messages" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."chat_messages" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."chat_messages" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."paper_pages" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."paper_pages" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."paper_pages" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."paper_pages" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."relationship_spaces" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."relationship_spaces" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."relationship_spaces" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."relationship_spaces" TO "service_role";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."space_members" TO "anon", "authenticated";

REVOKE ALL ON TABLE "public"."space_members" FROM "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."space_members" TO "postgres";

GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE "public"."space_members" TO "service_role";

