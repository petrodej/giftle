toc.dat                                                                                             0000600 0004000 0002000 00000162240 14754424543 0014460 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        PGDMP                       }            postgres    15.8    17.2 |    �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                           false         �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                           false         �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                           false         �           1262    5    postgres    DATABASE     t   CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';
    DROP DATABASE postgres;
                     postgres    false         �           0    0    DATABASE postgres    COMMENT     N   COMMENT ON DATABASE postgres IS 'default administrative connection database';
                        postgres    false    4020         �           0    0    DATABASE postgres    ACL     2   GRANT ALL ON DATABASE postgres TO dashboard_user;
                        postgres    false    4020         �           0    0    postgres    DATABASE PROPERTIES     >   ALTER DATABASE postgres SET "app.settings.jwt_exp" TO '3600';
                          postgres    false                     2615    2200    public    SCHEMA        CREATE SCHEMA public;
    DROP SCHEMA public;
                     pg_database_owner    false         �           0    0    SCHEMA public    COMMENT     6   COMMENT ON SCHEMA public IS 'standard public schema';
                        pg_database_owner    false    23         �           0    0    SCHEMA public    ACL     �   GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;
                        pg_database_owner    false    23         �           1247    29388    member_status    TYPE     J   CREATE TYPE public.member_status AS ENUM (
    'active',
    'pending'
);
     DROP TYPE public.member_status;
       public               postgres    false    23         H           1255    32858    assign_random_purchaser(uuid)    FUNCTION     �  CREATE FUNCTION public.assign_random_purchaser(input_project_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  selected_user_id uuid;
  result json;
BEGIN
  -- Get random active member using table alias to avoid ambiguity
  SELECT pm.user_id INTO selected_user_id
  FROM project_members pm
  WHERE pm.project_id = input_project_id
    AND pm.status = 'active'
    AND pm.user_id IS NOT NULL
  ORDER BY random()
  LIMIT 1;

  -- Update project with selected purchaser
  UPDATE gift_projects
  SET purchaser_id = selected_user_id
  WHERE id = input_project_id;

  -- Return result
  SELECT json_build_object(
    'purchaser_id', selected_user_id
  ) INTO result;

  RETURN result;
END;
$$;
 E   DROP FUNCTION public.assign_random_purchaser(input_project_id uuid);
       public               postgres    false    23         �           0    0 7   FUNCTION assign_random_purchaser(input_project_id uuid)    ACL       GRANT ALL ON FUNCTION public.assign_random_purchaser(input_project_id uuid) TO anon;
GRANT ALL ON FUNCTION public.assign_random_purchaser(input_project_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.assign_random_purchaser(input_project_id uuid) TO service_role;
          public               postgres    false    328         I           1255    48862    check_member_email_conflicts()    FUNCTION     J  CREATE FUNCTION public.check_member_email_conflicts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  user_email text;
BEGIN
  -- If we're updating user_id and it's not null
  IF TG_OP = 'UPDATE' AND NEW.user_id IS NOT NULL THEN
    -- Get the user's email
    SELECT email INTO user_email
    FROM auth.users 
    WHERE id = NEW.user_id
    LIMIT 1;

    IF user_email IS NOT NULL THEN
      -- Update email field
      NEW.email := user_email;
    END IF;
  END IF;

  -- For both INSERT and UPDATE, check for duplicates
  IF EXISTS (
    SELECT 1 
    FROM project_members
    WHERE project_id = NEW.project_id 
    AND email = NEW.email
    AND (
      TG_OP = 'INSERT' 
      OR 
      (TG_OP = 'UPDATE' AND project_members.email != OLD.email)
    )
  ) THEN
    -- Instead of error, update the existing record
    IF TG_OP = 'INSERT' THEN
      -- Update the existing record with new data
      UPDATE project_members 
      SET 
        user_id = COALESCE(NEW.user_id, project_members.user_id),
        status = CASE 
          WHEN project_members.status = 'pending' AND NEW.status = 'active' 
          THEN 'active' 
          ELSE project_members.status 
        END
      WHERE project_id = NEW.project_id 
      AND email = NEW.email;
      
      RETURN NULL; -- Prevents the INSERT
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;
 5   DROP FUNCTION public.check_member_email_conflicts();
       public               postgres    false    23         �           0    0 '   FUNCTION check_member_email_conflicts()    ACL     �   GRANT ALL ON FUNCTION public.check_member_email_conflicts() TO anon;
GRANT ALL ON FUNCTION public.check_member_email_conflicts() TO authenticated;
GRANT ALL ON FUNCTION public.check_member_email_conflicts() TO service_role;
          public               postgres    false    329         K           1255    29504    check_voting_allowed()    FUNCTION     �  CREATE FUNCTION public.check_voting_allowed() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM gift_projects gp
    JOIN gift_suggestions gs ON gs.project_id = gp.id
    WHERE gs.id = NEW.suggestion_id
    AND (gp.voting_closed = true OR gp.status = 'completed')
  ) THEN
    RAISE EXCEPTION 'Voting is closed for this project';
  END IF;
  RETURN NEW;
END;
$$;
 -   DROP FUNCTION public.check_voting_allowed();
       public               postgres    false    23         �           0    0    FUNCTION check_voting_allowed()    ACL     �   GRANT ALL ON FUNCTION public.check_voting_allowed() TO anon;
GRANT ALL ON FUNCTION public.check_voting_allowed() TO authenticated;
GRANT ALL ON FUNCTION public.check_voting_allowed() TO service_role;
          public               postgres    false    587         �           1255    57183    generate_unique_code()    FUNCTION     �  CREATE FUNCTION public.generate_unique_code() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_code text;
  code_exists boolean;
  url_safe_chars text;
BEGIN
  -- Define URL-safe characters (alphanumeric only, no special chars)
  url_safe_chars := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  
  LOOP
    -- Generate a random 8-character code using only URL-safe characters
    new_code := '';
    FOR i IN 1..8 LOOP
      -- Random index into url_safe_chars (0-based)
      new_code := new_code || substr(
        url_safe_chars,
        floor(random() * length(url_safe_chars))::integer + 1,
        1
      );
    END LOOP;
    
    -- Check if code exists
    SELECT EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE invite_code = new_code
    ) INTO code_exists;
    
    -- Exit loop if code is unique
    EXIT WHEN NOT code_exists;
  END LOOP;
  
  RETURN new_code;
END;
$$;
 -   DROP FUNCTION public.generate_unique_code();
       public               postgres    false    23         �           0    0    FUNCTION generate_unique_code()    ACL     �   GRANT ALL ON FUNCTION public.generate_unique_code() TO anon;
GRANT ALL ON FUNCTION public.generate_unique_code() TO authenticated;
GRANT ALL ON FUNCTION public.generate_unique_code() TO service_role;
          public               postgres    false    421         �           1255    34308    get_setting(text)    FUNCTION     �   CREATE FUNCTION public.get_setting(setting_key text) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT value FROM app_settings WHERE key = setting_key;
$$;
 4   DROP FUNCTION public.get_setting(setting_key text);
       public               postgres    false    23         �           0    0 &   FUNCTION get_setting(setting_key text)    ACL     �   GRANT ALL ON FUNCTION public.get_setting(setting_key text) TO anon;
GRANT ALL ON FUNCTION public.get_setting(setting_key text) TO authenticated;
GRANT ALL ON FUNCTION public.get_setting(setting_key text) TO service_role;
          public               postgres    false    418         c           1255    57018    handle_member_updates()    FUNCTION     �  CREATE FUNCTION public.handle_member_updates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  _user_id uuid;
  _email text;
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- When a user joins
  IF TG_OP = 'INSERT' THEN
    -- Always set email to the authenticated user's email if available
    IF _email IS NOT NULL THEN
      NEW.email := _email;
    END IF;

    -- If user is authenticated, set their user_id and make them active
    IF _user_id IS NOT NULL THEN
      NEW.user_id := _user_id;
      NEW.status := 'active';
    ELSE
      -- For email-only invites, set as pending
      NEW.status := COALESCE(NEW.status, 'pending');
    END IF;
  END IF;

  -- When updating an existing member
  IF TG_OP = 'UPDATE' THEN
    -- If user_id is being set and was previously NULL
    IF NEW.user_id IS NOT NULL AND OLD.user_id IS NULL THEN
      -- Activate the membership and ensure email matches
      NEW.status := 'active';
      -- Update email if it was a pending invitation
      IF OLD.status = 'pending' AND _email IS NOT NULL THEN
        NEW.email := _email;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;
 .   DROP FUNCTION public.handle_member_updates();
       public               postgres    false    23         �           0    0     FUNCTION handle_member_updates()    ACL     �   GRANT ALL ON FUNCTION public.handle_member_updates() TO anon;
GRANT ALL ON FUNCTION public.handle_member_updates() TO authenticated;
GRANT ALL ON FUNCTION public.handle_member_updates() TO service_role;
          public               postgres    false    355         �           1255    57197    join_project(uuid, text)    FUNCTION     �  CREATE FUNCTION public.join_project(input_project_id uuid, input_invite_code text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  _user_id uuid;
  _email text;
  _log_id uuid;
  _project_exists boolean;
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- Create detailed log entry
  INSERT INTO pending_notifications (
    email,
    project_id,
    status,
    metadata
  ) VALUES (
    _email,
    input_project_id,
    'debug',
    jsonb_build_object(
      'function', 'join_project',
      'user_id', _user_id,
      'email', _email,
      'invite_code', input_invite_code,
      'start_time', now()
    )
  ) RETURNING id INTO _log_id;

  -- Verify user is authenticated
  IF _user_id IS NULL OR _email IS NULL THEN
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'User must be authenticated to join project',
      processed_at = now()
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'User must be authenticated to join project';
  END IF;

  -- Check if project exists and has matching invite code
  SELECT EXISTS (
    SELECT 1 
    FROM gift_projects gp
    WHERE gp.id = input_project_id 
    AND gp.invite_code = input_invite_code
  ) INTO _project_exists;

  IF NOT _project_exists THEN
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'Invalid project or invite code',
      processed_at = now()
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'Invalid project or invite code';
  END IF;

  -- Insert new membership, handling conflicts
  BEGIN
    -- First try to update any existing membership by email
    UPDATE project_members
    SET 
      user_id = _user_id,
      status = 'active'
    WHERE 
      project_id = input_project_id
      AND email = _email;

    -- If no rows were updated, try to update by user_id
    IF NOT FOUND THEN
      UPDATE project_members
      SET 
        email = _email,
        status = 'active'
      WHERE 
        project_id = input_project_id
        AND user_id = _user_id;
    END IF;

    -- If still no rows were updated, insert a new membership
    IF NOT FOUND THEN
      INSERT INTO project_members (
        project_id,
        email,
        user_id,
        status,
        role
      ) 
      VALUES (
        input_project_id,
        _email,
        _user_id,
        'active',
        'member'
      );
    END IF;

    -- Log success
    UPDATE pending_notifications
    SET 
      status = 'success',
      processed_at = now(),
      metadata = jsonb_build_object(
        'function', 'join_project',
        'user_id', _user_id,
        'email', _email,
        'invite_code', input_invite_code,
        'start_time', (metadata->>'start_time')::timestamptz,
        'end_time', now(),
        'action', 'upsert'
      )
    WHERE id = _log_id;

  EXCEPTION WHEN OTHERS THEN
    -- Log error details
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = SQLERRM,
      processed_at = now(),
      metadata = jsonb_build_object(
        'function', 'join_project',
        'user_id', _user_id,
        'email', _email,
        'invite_code', input_invite_code,
        'start_time', (metadata->>'start_time')::timestamptz,
        'end_time', now(),
        'error_code', SQLSTATE,
        'error_detail', SQLERRM
      )
    WHERE id = _log_id;
    
    RAISE;
  END;
END;
$$;
 R   DROP FUNCTION public.join_project(input_project_id uuid, input_invite_code text);
       public               postgres    false    23         �           0    0 D   FUNCTION join_project(input_project_id uuid, input_invite_code text)    ACL     7  GRANT ALL ON FUNCTION public.join_project(input_project_id uuid, input_invite_code text) TO anon;
GRANT ALL ON FUNCTION public.join_project(input_project_id uuid, input_invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.join_project(input_project_id uuid, input_invite_code text) TO service_role;
          public               postgres    false    422         P           1255    41031    track_pending_notification()    FUNCTION       CREATE FUNCTION public.track_pending_notification() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  INSERT INTO pending_notifications (email, project_id)
  VALUES (NEW.email, NEW.project_id);
  RETURN NEW;
END;
$$;
 3   DROP FUNCTION public.track_pending_notification();
       public               postgres    false    23         �           0    0 %   FUNCTION track_pending_notification()    ACL     �   GRANT ALL ON FUNCTION public.track_pending_notification() TO anon;
GRANT ALL ON FUNCTION public.track_pending_notification() TO authenticated;
GRANT ALL ON FUNCTION public.track_pending_notification() TO service_role;
          public               postgres    false    336         V           1255    56970     validate_invite_code(uuid, text)    FUNCTION     M  CREATE FUNCTION public.validate_invite_code(project_id uuid, invite_code text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM gift_projects 
    WHERE id = project_id 
    AND invite_code = validate_invite_code.invite_code
  );
END;
$$;
 N   DROP FUNCTION public.validate_invite_code(project_id uuid, invite_code text);
       public               postgres    false    23         �           0    0 @   FUNCTION validate_invite_code(project_id uuid, invite_code text)    ACL     +  GRANT ALL ON FUNCTION public.validate_invite_code(project_id uuid, invite_code text) TO anon;
GRANT ALL ON FUNCTION public.validate_invite_code(project_id uuid, invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.validate_invite_code(project_id uuid, invite_code text) TO service_role;
          public               postgres    false    342         2           1259    34300    app_settings    TABLE     U   CREATE TABLE public.app_settings (
    key text NOT NULL,
    value text NOT NULL
);
     DROP TABLE public.app_settings;
       public         heap r       postgres    false    23         �           0    0    TABLE app_settings    ACL     =  GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.app_settings TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.app_settings TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.app_settings TO service_role;
          public               postgres    false    306         #           1259    29051    gift_projects    TABLE     m  CREATE TABLE public.gift_projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_by uuid,
    recipient_name text NOT NULL,
    birth_date date,
    interests text[],
    created_at timestamp with time zone DEFAULT now(),
    project_date date NOT NULL,
    status text DEFAULT 'active'::text,
    selected_gift_id uuid,
    purchaser_id uuid,
    invite_code text DEFAULT encode(extensions.gen_random_bytes(6), 'base64'::text),
    parent_project_id uuid,
    is_recurring boolean DEFAULT false,
    next_occurrence_date timestamp with time zone,
    min_budget numeric(10,2),
    max_budget numeric(10,2),
    budget_type text DEFAULT 'per_person'::text,
    voting_closed boolean DEFAULT false,
    completed_at timestamp with time zone,
    CONSTRAINT gift_projects_budget_type_check CHECK ((budget_type = ANY (ARRAY['per_person'::text, 'total'::text])))
);
 !   DROP TABLE public.gift_projects;
       public         heap r       postgres    false    23         �           0    0    TABLE gift_projects    ACL       GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_projects TO service_role;
GRANT SELECT ON TABLE public.gift_projects TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_projects TO authenticated;
          public               postgres    false    291         %           1259    29093    gift_suggestions    TABLE       CREATE TABLE public.gift_suggestions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    suggested_by uuid,
    title text NOT NULL,
    description text,
    price numeric(10,2),
    url text,
    created_at timestamp with time zone DEFAULT now(),
    is_ai_generated boolean DEFAULT false,
    confidence_score numeric(4,3),
    source_suggestion_id uuid
);
 $   DROP TABLE public.gift_suggestions;
       public         heap r       postgres    false    23         �           0    0    TABLE gift_suggestions    ACL     I  GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_suggestions TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_suggestions TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_suggestions TO service_role;
          public               postgres    false    293         .           1259    29366    pending_invitations    TABLE     	  CREATE TABLE public.pending_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    email text NOT NULL,
    invite_code text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'pending'::text
);
 '   DROP TABLE public.pending_invitations;
       public         heap r       postgres    false    23         �           0    0    TABLE pending_invitations    ACL     R  GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_invitations TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_invitations TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_invitations TO service_role;
          public               postgres    false    302         3           1259    41010    pending_notifications    TABLE     L  CREATE TABLE public.pending_notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    project_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    processed_at timestamp with time zone,
    status text DEFAULT 'pending'::text,
    metadata jsonb,
    error_message text
);
 )   DROP TABLE public.pending_notifications;
       public         heap r       postgres    false    23         �           0    0    TABLE pending_notifications    ACL     X  GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_notifications TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_notifications TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_notifications TO service_role;
          public               postgres    false    307         "           1259    29037    profiles    TABLE     �   CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    full_name text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
    DROP TABLE public.profiles;
       public         heap r       postgres    false    23         �           0    0    TABLE profiles    ACL     1  GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.profiles TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.profiles TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.profiles TO service_role;
          public               postgres    false    290         $           1259    29074    project_members    TABLE     �  CREATE TABLE public.project_members (
    project_id uuid NOT NULL,
    user_id uuid,
    joined_at timestamp with time zone DEFAULT now(),
    role text DEFAULT 'member'::text,
    status public.member_status DEFAULT 'active'::public.member_status NOT NULL,
    email text,
    CONSTRAINT project_members_user_or_email_check CHECK (((user_id IS NOT NULL) OR (email IS NOT NULL)))
);
 #   DROP TABLE public.project_members;
       public         heap r       postgres    false    1243    23    1243         �           0    0    TABLE project_members    ACL     F  GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.project_members TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.project_members TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.project_members TO service_role;
          public               postgres    false    292         &           1259    29112    votes    TABLE       CREATE TABLE public.votes (
    suggestion_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    medal text,
    CONSTRAINT votes_medal_check CHECK ((medal = ANY (ARRAY['gold'::text, 'silver'::text, 'bronze'::text])))
);
    DROP TABLE public.votes;
       public         heap r       postgres    false    23         �           0    0    TABLE votes    ACL     (  GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.votes TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.votes TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.votes TO service_role;
          public               postgres    false    294         �          0    34300    app_settings 
   TABLE DATA           2   COPY public.app_settings (key, value) FROM stdin;
    public               postgres    false    306       4013.dat �          0    29051    gift_projects 
   TABLE DATA           &  COPY public.gift_projects (id, created_by, recipient_name, birth_date, interests, created_at, project_date, status, selected_gift_id, purchaser_id, invite_code, parent_project_id, is_recurring, next_occurrence_date, min_budget, max_budget, budget_type, voting_closed, completed_at) FROM stdin;
    public               postgres    false    291       4008.dat �          0    29093    gift_suggestions 
   TABLE DATA           �   COPY public.gift_suggestions (id, project_id, suggested_by, title, description, price, url, created_at, is_ai_generated, confidence_score, source_suggestion_id) FROM stdin;
    public               postgres    false    293       4010.dat �          0    29366    pending_invitations 
   TABLE DATA           e   COPY public.pending_invitations (id, project_id, email, invite_code, created_at, status) FROM stdin;
    public               postgres    false    302       4012.dat �          0    41010    pending_notifications 
   TABLE DATA           �   COPY public.pending_notifications (id, email, project_id, created_at, processed_at, status, metadata, error_message) FROM stdin;
    public               postgres    false    307       4014.dat �          0    29037    profiles 
   TABLE DATA           \   COPY public.profiles (id, email, full_name, avatar_url, created_at, updated_at) FROM stdin;
    public               postgres    false    290       4007.dat �          0    29074    project_members 
   TABLE DATA           ^   COPY public.project_members (project_id, user_id, joined_at, role, status, email) FROM stdin;
    public               postgres    false    292       4009.dat �          0    29112    votes 
   TABLE DATA           J   COPY public.votes (suggestion_id, user_id, created_at, medal) FROM stdin;
    public               postgres    false    294       4011.dat �           2606    34306    app_settings app_settings_pkey 
   CONSTRAINT     ]   ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (key);
 H   ALTER TABLE ONLY public.app_settings DROP CONSTRAINT app_settings_pkey;
       public                 postgres    false    306         �           2606    29063 +   gift_projects gift_projects_invite_code_key 
   CONSTRAINT     m   ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_invite_code_key UNIQUE (invite_code);
 U   ALTER TABLE ONLY public.gift_projects DROP CONSTRAINT gift_projects_invite_code_key;
       public                 postgres    false    291         �           2606    29061     gift_projects gift_projects_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.gift_projects DROP CONSTRAINT gift_projects_pkey;
       public                 postgres    false    291         �           2606    29101 &   gift_suggestions gift_suggestions_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.gift_suggestions DROP CONSTRAINT gift_suggestions_pkey;
       public                 postgres    false    293         �           2606    29496 '   votes one_medal_per_user_per_suggestion 
   CONSTRAINT     t   ALTER TABLE ONLY public.votes
    ADD CONSTRAINT one_medal_per_user_per_suggestion UNIQUE (suggestion_id, user_id);
 Q   ALTER TABLE ONLY public.votes DROP CONSTRAINT one_medal_per_user_per_suggestion;
       public                 postgres    false    294    294         �           2606    29375 ,   pending_invitations pending_invitations_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.pending_invitations
    ADD CONSTRAINT pending_invitations_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.pending_invitations DROP CONSTRAINT pending_invitations_pkey;
       public                 postgres    false    302         �           2606    29377 <   pending_invitations pending_invitations_project_id_email_key 
   CONSTRAINT     �   ALTER TABLE ONLY public.pending_invitations
    ADD CONSTRAINT pending_invitations_project_id_email_key UNIQUE (project_id, email);
 f   ALTER TABLE ONLY public.pending_invitations DROP CONSTRAINT pending_invitations_project_id_email_key;
       public                 postgres    false    302    302         �           2606    41019 0   pending_notifications pending_notifications_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.pending_notifications
    ADD CONSTRAINT pending_notifications_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.pending_notifications DROP CONSTRAINT pending_notifications_pkey;
       public                 postgres    false    307         �           2606    29045    profiles profiles_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.profiles DROP CONSTRAINT profiles_pkey;
       public                 postgres    false    290         �           2606    48865 4   project_members project_members_project_email_unique 
   CONSTRAINT     |   ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_email_unique UNIQUE (project_id, email);
 ^   ALTER TABLE ONLY public.project_members DROP CONSTRAINT project_members_project_email_unique;
       public                 postgres    false    292    292         �           2606    29117    votes votes_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (suggestion_id, user_id);
 :   ALTER TABLE ONLY public.votes DROP CONSTRAINT votes_pkey;
       public                 postgres    false    294    294         �           1259    29385    pending_invitations_email_idx    INDEX     ^   CREATE INDEX pending_invitations_email_idx ON public.pending_invitations USING btree (email);
 1   DROP INDEX public.pending_invitations_email_idx;
       public                 postgres    false    302         �           1259    29386 #   pending_invitations_invite_code_idx    INDEX     j   CREATE INDEX pending_invitations_invite_code_idx ON public.pending_invitations USING btree (invite_code);
 7   DROP INDEX public.pending_invitations_invite_code_idx;
       public                 postgres    false    302         �           1259    29394    project_members_email_idx    INDEX     V   CREATE INDEX project_members_email_idx ON public.project_members USING btree (email);
 -   DROP INDEX public.project_members_email_idx;
       public                 postgres    false    292         �           2620    48866 ,   project_members check_member_email_conflicts    TRIGGER     �   CREATE TRIGGER check_member_email_conflicts BEFORE INSERT OR UPDATE ON public.project_members FOR EACH ROW EXECUTE FUNCTION public.check_member_email_conflicts();
 E   DROP TRIGGER check_member_email_conflicts ON public.project_members;
       public               postgres    false    329    292         �           2620    29505    votes enforce_voting_allowed    TRIGGER     �   CREATE TRIGGER enforce_voting_allowed BEFORE INSERT OR UPDATE ON public.votes FOR EACH ROW EXECUTE FUNCTION public.check_voting_allowed();
 5   DROP TRIGGER enforce_voting_allowed ON public.votes;
       public               postgres    false    587    294         �           2620    57019    project_members member_updates    TRIGGER     �   CREATE TRIGGER member_updates BEFORE INSERT OR UPDATE ON public.project_members FOR EACH ROW EXECUTE FUNCTION public.handle_member_updates();
 7   DROP TRIGGER member_updates ON public.project_members;
       public               postgres    false    355    292         �           2620    41032 #   project_members track_member_invite    TRIGGER     �   CREATE TRIGGER track_member_invite AFTER INSERT ON public.project_members FOR EACH ROW WHEN (((new.status = 'pending'::public.member_status) AND (new.email IS NOT NULL))) EXECUTE FUNCTION public.track_pending_notification();
 <   DROP TRIGGER track_member_invite ON public.project_members;
       public               postgres    false    336    292    1243    292    292         �           2606    29064 +   gift_projects gift_projects_created_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);
 U   ALTER TABLE ONLY public.gift_projects DROP CONSTRAINT gift_projects_created_by_fkey;
       public               postgres    false    290    291    3781         �           2606    29147 2   gift_projects gift_projects_parent_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_parent_project_id_fkey FOREIGN KEY (parent_project_id) REFERENCES public.gift_projects(id);
 \   ALTER TABLE ONLY public.gift_projects DROP CONSTRAINT gift_projects_parent_project_id_fkey;
       public               postgres    false    291    291    3785         �           2606    29069 -   gift_projects gift_projects_purchaser_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_purchaser_id_fkey FOREIGN KEY (purchaser_id) REFERENCES public.profiles(id);
 W   ALTER TABLE ONLY public.gift_projects DROP CONSTRAINT gift_projects_purchaser_id_fkey;
       public               postgres    false    3781    291    290         �           2606    29102 1   gift_suggestions gift_suggestions_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;
 [   ALTER TABLE ONLY public.gift_suggestions DROP CONSTRAINT gift_suggestions_project_id_fkey;
       public               postgres    false    3785    291    293         �           2606    29153 ;   gift_suggestions gift_suggestions_source_suggestion_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_source_suggestion_id_fkey FOREIGN KEY (source_suggestion_id) REFERENCES public.gift_suggestions(id);
 e   ALTER TABLE ONLY public.gift_suggestions DROP CONSTRAINT gift_suggestions_source_suggestion_id_fkey;
       public               postgres    false    3790    293    293         �           2606    29107 3   gift_suggestions gift_suggestions_suggested_by_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_suggested_by_fkey FOREIGN KEY (suggested_by) REFERENCES public.profiles(id);
 ]   ALTER TABLE ONLY public.gift_suggestions DROP CONSTRAINT gift_suggestions_suggested_by_fkey;
       public               postgres    false    3781    290    293         �           2606    29378 7   pending_invitations pending_invitations_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.pending_invitations
    ADD CONSTRAINT pending_invitations_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;
 a   ALTER TABLE ONLY public.pending_invitations DROP CONSTRAINT pending_invitations_project_id_fkey;
       public               postgres    false    3785    291    302         �           2606    48847 ;   pending_notifications pending_notifications_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.pending_notifications
    ADD CONSTRAINT pending_notifications_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;
 e   ALTER TABLE ONLY public.pending_notifications DROP CONSTRAINT pending_notifications_project_id_fkey;
       public               postgres    false    291    3785    307         �           2606    29046    profiles profiles_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
 C   ALTER TABLE ONLY public.profiles DROP CONSTRAINT profiles_id_fkey;
       public               postgres    false    290         �           2606    29083 /   project_members project_members_project_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;
 Y   ALTER TABLE ONLY public.project_members DROP CONSTRAINT project_members_project_id_fkey;
       public               postgres    false    291    3785    292         �           2606    29088 ,   project_members project_members_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
 V   ALTER TABLE ONLY public.project_members DROP CONSTRAINT project_members_user_id_fkey;
       public               postgres    false    3781    290    292         �           2606    29118    votes votes_suggestion_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.gift_suggestions(id) ON DELETE CASCADE;
 H   ALTER TABLE ONLY public.votes DROP CONSTRAINT votes_suggestion_id_fkey;
       public               postgres    false    3790    294    293         �           2606    29123    votes votes_user_id_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
 B   ALTER TABLE ONLY public.votes DROP CONSTRAINT votes_user_id_fkey;
       public               postgres    false    294    290    3781         �           3256    57189    gift_projects Access via invite    POLICY     j   CREATE POLICY "Access via invite" ON public.gift_projects FOR SELECT TO authenticated, anon USING (true);
 9   DROP POLICY "Access via invite" ON public.gift_projects;
       public               postgres    false    291         �           3256    54664     gift_suggestions Add suggestions    POLICY     �  CREATE POLICY "Add suggestions" ON public.gift_suggestions FOR INSERT TO authenticated WITH CHECK (((EXISTS ( SELECT 1
   FROM (public.project_members pm
     JOIN public.gift_projects gp ON ((gp.id = pm.project_id)))
  WHERE ((pm.project_id = gift_suggestions.project_id) AND (((pm.status = 'active'::public.member_status) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email()))) OR (gp.created_by = auth.uid()))))) AND (suggested_by = auth.uid())));
 :   DROP POLICY "Add suggestions" ON public.gift_suggestions;
       public               postgres    false    292    291    291    292    292    292    293    293    1243    293         �           3256    48854 G   pending_notifications Allow authenticated users to insert notifications    POLICY     �   CREATE POLICY "Allow authenticated users to insert notifications" ON public.pending_notifications FOR INSERT TO authenticated WITH CHECK (true);
 a   DROP POLICY "Allow authenticated users to insert notifications" ON public.pending_notifications;
       public               postgres    false    307         �           3256    48856 G   pending_notifications Allow authenticated users to update notifications    POLICY     �   CREATE POLICY "Allow authenticated users to update notifications" ON public.pending_notifications FOR UPDATE TO authenticated USING (true) WITH CHECK (true);
 a   DROP POLICY "Allow authenticated users to update notifications" ON public.pending_notifications;
       public               postgres    false    307         �           3256    48855 E   pending_notifications Allow authenticated users to view notifications    POLICY     �   CREATE POLICY "Allow authenticated users to view notifications" ON public.pending_notifications FOR SELECT TO authenticated USING (true);
 _   DROP POLICY "Allow authenticated users to view notifications" ON public.pending_notifications;
       public               postgres    false    307         �           3256    34309 #   app_settings Allow reading settings    POLICY     h   CREATE POLICY "Allow reading settings" ON public.app_settings FOR SELECT TO authenticated USING (true);
 =   DROP POLICY "Allow reading settings" ON public.app_settings;
       public               postgres    false    306         �           3256    29130 -   gift_projects Anyone can create gift projects    POLICY     w   CREATE POLICY "Anyone can create gift projects" ON public.gift_projects FOR INSERT TO authenticated WITH CHECK (true);
 G   DROP POLICY "Anyone can create gift projects" ON public.gift_projects;
       public               postgres    false    291         �           3256    29498    votes Cast votes    POLICY     l  CREATE POLICY "Cast votes" ON public.votes FOR INSERT TO authenticated WITH CHECK (((EXISTS ( SELECT 1
   FROM (public.gift_suggestions gs
     JOIN public.project_members pm ON ((pm.project_id = gs.project_id)))
  WHERE ((gs.id = votes.suggestion_id) AND (pm.user_id = auth.uid()) AND (pm.status = 'active'::public.member_status)))) AND (auth.uid() = user_id)));
 *   DROP POLICY "Cast votes" ON public.votes;
       public               postgres    false    293    292    292    292    294    1243    294    294    293         �           3256    57190    gift_projects Create projects    POLICY     |   CREATE POLICY "Create projects" ON public.gift_projects FOR INSERT TO authenticated WITH CHECK ((created_by = auth.uid()));
 7   DROP POLICY "Create projects" ON public.gift_projects;
       public               postgres    false    291    291         �           3256    29501    votes Delete own votes    POLICY     m   CREATE POLICY "Delete own votes" ON public.votes FOR DELETE TO authenticated USING ((auth.uid() = user_id));
 0   DROP POLICY "Delete own votes" ON public.votes;
       public               postgres    false    294    294         �           3256    52264 &   project_members Delete project members    POLICY     6  CREATE POLICY "Delete project members" ON public.project_members FOR DELETE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))) OR ((email = auth.email()) OR (user_id = auth.uid()))));
 @   DROP POLICY "Delete project members" ON public.project_members;
       public               postgres    false    291    291    292    292    292    292         �           3256    54668 #   gift_suggestions Delete suggestions    POLICY     
  CREATE POLICY "Delete suggestions" ON public.gift_suggestions FOR DELETE TO authenticated USING (((suggested_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.gift_projects gp
  WHERE ((gp.id = gift_suggestions.project_id) AND (gp.created_by = auth.uid()))))));
 =   DROP POLICY "Delete suggestions" ON public.gift_suggestions;
       public               postgres    false    293    293    291    291    293         �           3256    56971    project_members Insert members    POLICY     �  CREATE POLICY "Insert members" ON public.project_members FOR INSERT TO authenticated WITH CHECK ((((email = auth.email()) AND (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE (gift_projects.id = project_members.project_id)))) OR (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid()))))));
 8   DROP POLICY "Insert members" ON public.project_members;
       public               postgres    false    292    292    291    291    292         �           3256    29489    gift_projects Insert projects    POLICY     |   CREATE POLICY "Insert projects" ON public.gift_projects FOR INSERT TO authenticated WITH CHECK ((created_by = auth.uid()));
 7   DROP POLICY "Insert projects" ON public.gift_projects;
       public               postgres    false    291    291         �           3256    57191    gift_projects Manage projects    POLICY     �   CREATE POLICY "Manage projects" ON public.gift_projects TO authenticated USING ((created_by = auth.uid())) WITH CHECK ((created_by = auth.uid()));
 7   DROP POLICY "Manage projects" ON public.gift_projects;
       public               postgres    false    291    291    291         �           3256    29131 -   gift_projects Members can view their projects    POLICY       CREATE POLICY "Members can view their projects" ON public.gift_projects FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.project_members
  WHERE ((project_members.project_id = gift_projects.id) AND (project_members.user_id = auth.uid())))));
 G   DROP POLICY "Members can view their projects" ON public.gift_projects;
       public               postgres    false    292    292    291    291         �           3256    29383 9   pending_invitations Project admins can manage invitations    POLICY       CREATE POLICY "Project admins can manage invitations" ON public.pending_invitations TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.project_members
  WHERE ((project_members.project_id = pending_invitations.project_id) AND (project_members.user_id = auth.uid()) AND (project_members.role = 'admin'::text))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.project_members
  WHERE ((project_members.project_id = pending_invitations.project_id) AND (project_members.user_id = auth.uid()) AND (project_members.role = 'admin'::text)))));
 S   DROP POLICY "Project admins can manage invitations" ON public.pending_invitations;
       public               postgres    false    292    302    292    292    292    302    302    292    292         �           3256    56972    project_members Update members    POLICY       CREATE POLICY "Update members" ON public.project_members FOR UPDATE TO authenticated USING (((email = auth.email()) OR (user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))))) WITH CHECK (((email = auth.email()) OR (user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid()))))));
 8   DROP POLICY "Update members" ON public.project_members;
       public               postgres    false    292    292    292    291    292    292    292    291    291    291    292         �           3256    54666 '   gift_suggestions Update own suggestions    POLICY     �  CREATE POLICY "Update own suggestions" ON public.gift_suggestions FOR UPDATE TO authenticated USING (((suggested_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM (public.project_members pm
     JOIN public.gift_projects gp ON ((gp.id = pm.project_id)))
  WHERE ((pm.project_id = gift_suggestions.project_id) AND (((pm.status = 'active'::public.member_status) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email()))) OR (gp.created_by = auth.uid()))))))) WITH CHECK ((suggested_by = auth.uid()));
 A   DROP POLICY "Update own suggestions" ON public.gift_suggestions;
       public               postgres    false    291    291    292    292    292    292    293    293    1243    293    293         �           3256    29500    votes Update own votes    POLICY     �   CREATE POLICY "Update own votes" ON public.votes FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));
 0   DROP POLICY "Update own votes" ON public.votes;
       public               postgres    false    294    294    294         �           3256    52262 &   project_members Update project members    POLICY       CREATE POLICY "Update project members" ON public.project_members FOR UPDATE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))) OR ((email = auth.email()) OR (user_id = auth.uid())))) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))) OR ((email = auth.email()) OR (user_id = auth.uid()))));
 @   DROP POLICY "Update project members" ON public.project_members;
       public               postgres    false    291    292    292    292    292    291    291    292    292    292    291         �           3256    29168 +   profiles Users can manage their own profile    POLICY     �   CREATE POLICY "Users can manage their own profile" ON public.profiles TO authenticated USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));
 E   DROP POLICY "Users can manage their own profile" ON public.profiles;
       public               postgres    false    290    290    290         �           3256    52260 $   project_members View project members    POLICY     i   CREATE POLICY "View project members" ON public.project_members FOR SELECT TO authenticated USING (true);
 >   DROP POLICY "View project members" ON public.project_members;
       public               postgres    false    292         �           3256    29497    votes View project votes    POLICY     R  CREATE POLICY "View project votes" ON public.votes FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.gift_suggestions gs
     JOIN public.project_members pm ON ((pm.project_id = gs.project_id)))
  WHERE ((gs.id = votes.suggestion_id) AND (pm.user_id = auth.uid()) AND (pm.status = 'active'::public.member_status)))));
 2   DROP POLICY "View project votes" ON public.votes;
       public               postgres    false    293    292    292    292    293    294    1243    294         �           3256    57188    gift_projects View projects    POLICY       CREATE POLICY "View projects" ON public.gift_projects FOR SELECT TO authenticated USING (((created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.project_members pm
  WHERE ((pm.project_id = gift_projects.id) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email())))))));
 5   DROP POLICY "View projects" ON public.gift_projects;
       public               postgres    false    291    291    292    292    292    291         �           3256    54662 !   gift_suggestions View suggestions    POLICY     �  CREATE POLICY "View suggestions" ON public.gift_suggestions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.project_members pm
     JOIN public.gift_projects gp ON ((gp.id = pm.project_id)))
  WHERE ((pm.project_id = gift_suggestions.project_id) AND (((pm.status = 'active'::public.member_status) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email()))) OR (gp.created_by = auth.uid()))))));
 ;   DROP POLICY "View suggestions" ON public.gift_suggestions;
       public               postgres    false    291    292    293    1243    292    292    293    292    291         �           0    34300    app_settings    ROW SECURITY     :   ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;          public               postgres    false    306         �           0    29051    gift_projects    ROW SECURITY     ;   ALTER TABLE public.gift_projects ENABLE ROW LEVEL SECURITY;          public               postgres    false    291         �           0    29093    gift_suggestions    ROW SECURITY     >   ALTER TABLE public.gift_suggestions ENABLE ROW LEVEL SECURITY;          public               postgres    false    293         �           0    29366    pending_invitations    ROW SECURITY     A   ALTER TABLE public.pending_invitations ENABLE ROW LEVEL SECURITY;          public               postgres    false    302         �           0    41010    pending_notifications    ROW SECURITY     C   ALTER TABLE public.pending_notifications ENABLE ROW LEVEL SECURITY;          public               postgres    false    307         �           0    29037    profiles    ROW SECURITY     6   ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;          public               postgres    false    290         �           0    29074    project_members    ROW SECURITY     =   ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;          public               postgres    false    292         �           0    29112    votes    ROW SECURITY     3   ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;          public               postgres    false    294         �	           826    16484     DEFAULT PRIVILEGES FOR SEQUENCES    DEFAULT ACL     �  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
          public               postgres    false    23         �	           826    16485     DEFAULT PRIVILEGES FOR SEQUENCES    DEFAULT ACL     �  ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;
          public               supabase_admin    false    23         �	           826    16483     DEFAULT PRIVILEGES FOR FUNCTIONS    DEFAULT ACL     �  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;
          public               postgres    false    23         �	           826    16487     DEFAULT PRIVILEGES FOR FUNCTIONS    DEFAULT ACL     �  ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;
          public               supabase_admin    false    23         �	           826    16482    DEFAULT PRIVILEGES FOR TABLES    DEFAULT ACL     I  ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO service_role;
          public               postgres    false    23         �	           826    16486    DEFAULT PRIVILEGES FOR TABLES    DEFAULT ACL     a  ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO service_role;
          public               supabase_admin    false    23                                                                                                                                                                                                                                                                                                                                                                        4013.dat                                                                                            0000600 0004000 0002000 00000000256 14754424543 0014260 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        resend_key	re_SpndzDav_PwEmiXpFw5gFrPn1yS2rXPLR
base_url	https://giftle.stackblitz.io
edge_function_url	https://zqedbnnolhizvogksovc.supabase.co/functions/v1/send-email
\.


                                                                                                                                                                                                                                                                                                                                                  4008.dat                                                                                            0000600 0004000 0002000 00000006452 14754424544 0014271 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        f23939ec-34e3-4470-ae83-6980445507dd	90423df2-520b-43bf-b404-f74427b5ccdd	Marko	\N	{chess,guitars,"classical rock music","easy plants"}	2025-01-28 20:52:25.695174+00	2025-02-06	active	\N	90423df2-520b-43bf-b404-f74427b5ccdd	e8iew5Kq	\N	t	\N	20.00	20.00	per_person	f	\N
3b10fd65-98af-4dec-9d86-4813b07d5d47	90423df2-520b-43bf-b404-f74427b5ccdd	Bor2	\N	{chess,guitars,"classical rock music","easy plants",pool,badbinton}	2025-01-29 19:46:55.38114+00	2025-01-03	active	\N	90423df2-520b-43bf-b404-f74427b5ccdd	nK3MOhus	\N	t	\N	20.00	20.00	per_person	f	\N
ee259a72-8428-4dbd-ba0e-0ff9dbec2b07	ee0d01af-3251-41a7-b99c-bf6ed46b3f4c	Dejan	1990-05-01	{"World of Warcraft","table games",hiking,sex}	2025-01-26 11:25:28.032317+00	2025-05-03	active	\N	ee0d01af-3251-41a7-b99c-bf6ed46b3f4c	bExwe/Oy	\N	f	\N	150.00	200.00	total	f	\N
8aa662ad-6e34-41c5-ba25-e0c6acde5716	2c7ad380-1650-4fbc-99fa-49c4259f3b26	Ana	\N	{plushies,dildos,"cute things",flute,stickers,vibrators,plants}	2025-02-02 15:51:30.684307+00	2025-02-09	active	\N	2c7ad380-1650-4fbc-99fa-49c4259f3b26	L5rX8ett	\N	t	\N	20.00	20.00	per_person	f	\N
00c20fee-e868-4195-95ce-d6aa33f1df44	2c7ad380-1650-4fbc-99fa-49c4259f3b26	Jaz	\N	{plushies,dildos,"cute things",flute,stickers,vibrators,plants}	2025-02-09 19:37:43.346265+00	2025-02-09	active	\N	\N	AY9r/WBc	\N	f	\N	20.00	20.00	per_person	f	\N
4e4ee382-578e-4b98-9bf5-9bd25fa09f4e	90423df2-520b-43bf-b404-f74427b5ccdd	Bor	\N	{"road bikes",fitness,hiking,puzzles}	2025-01-27 21:35:52.007715+00	2026-02-09	active	\N	\N	Uv5iDxcG	5c02ef68-7ac1-42e8-8387-6b2f16ba2646	t	\N	50.00	200.00	total	f	\N
dc95d1c4-9d1e-4f66-b682-b953d9eeacb2	f1f919ae-b731-43d9-93c8-42215449d531	En drug	2025-01-31	{granate,fireworks,lopata}	2025-01-27 23:00:43.351119+00	2025-01-30	active	\N	f1f919ae-b731-43d9-93c8-42215449d531	ZwQKVJ4z	\N	t	\N	20.00	20.00	per_person	f	\N
5758eb90-2553-478b-842e-086833112b4a	2c7ad380-1650-4fbc-99fa-49c4259f3b26	Anauiiou	\N	{plushies,dildos,"cute things",flute,stickers,vibrators,plants}	2025-02-10 07:49:31.547453+00	2025-02-01	active	\N	\N	0i3hXiyx	\N	f	\N	20.00	20.00	per_person	f	\N
e910db66-d8dc-4977-a41f-c6ec0aa2f021	e4606cb8-9368-492e-93f4-960c9b41b1db	pipi	\N	{kjhjhj}	2025-02-14 06:19:47.313532+00	2025-02-15	active	\N	\N	OIRH7Qjv	\N	f	\N	20.00	20.00	per_person	t	\N
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2c7ad380-1650-4fbc-99fa-49c4259f3b26	idemoo	\N	{}	2025-02-16 10:00:17.471125+00	2025-02-20	active	\N	\N	ToVKhVA9	\N	f	\N	20.00	20.00	per_person	t	\N
9da7ac8c-84d8-4b8a-8c7d-437b0e8c8ada	d2cb7d57-230d-4060-9d93-0cdffec03f87	pkopkop	\N	{}	2025-02-16 10:19:55.974646+00	2025-02-06	active	\N	\N	ZWNSpp/U	\N	f	\N	20.00	20.00	per_person	t	\N
7a29c5ef-9c21-4d2d-8d86-fb7368748d00	90423df2-520b-43bf-b404-f74427b5ccdd	Markec	\N	{granate,fireworks,lopata}	2025-01-29 18:57:41.250256+00	2025-01-29	active	\N	90423df2-520b-43bf-b404-f74427b5ccdd	IS5DV/dR	\N	t	\N	20.00	20.00	per_person	f	\N
5c02ef68-7ac1-42e8-8387-6b2f16ba2646	90423df2-520b-43bf-b404-f74427b5ccdd	Bor	\N	{"road bikes",fitness,hiking,puzzles}	2025-01-26 10:33:33.361888+00	2025-02-09	active	\N	\N	WoSxU1bh	\N	t	\N	50.00	200.00	total	f	\N
9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	90423df2-520b-43bf-b404-f74427b5ccdd	Ana	\N	{plants,geeky,plushies,flute,stickers}	2025-01-26 08:57:10.892044+00	2025-02-08	active	\N	90423df2-520b-43bf-b404-f74427b5ccdd	y7Tzv+Xh	\N	t	\N	20.00	20.00	per_person	f	\N
\.


                                                                                                                                                                                                                      4010.dat                                                                                            0000600 0004000 0002000 00000003471 14754424544 0014260 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        1cb8a2a4-84a9-48dc-bf6f-ef64a833e0fa	9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	90423df2-520b-43bf-b404-f74427b5ccdd	pokemon	Pokemon	50.00	\N	2025-01-26 09:46:30.023971+00	f	\N	\N
cf7458e7-5e05-4c8e-b066-ccc857b69b5b	ee259a72-8428-4dbd-ba0e-0ff9dbec2b07	ee0d01af-3251-41a7-b99c-bf6ed46b3f4c	Dildo	Small anal metalic dildi, white	79.99	\N	2025-01-26 11:26:32.658344+00	f	\N	\N
a5dcc3f3-147f-4aff-b87d-f08cbf0f3d49	9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	90423df2-520b-43bf-b404-f74427b5ccdd	Some cool plant	This is my plant description. Tigrasta alokasija. b/c y not.	50.00	https://alokasija.net	2025-01-26 16:28:23.360293+00	f	\N	\N
1d08e431-d026-4458-85b4-a89e2f046a89	9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	90423df2-520b-43bf-b404-f74427b5ccdd	Stickers	Some cool stickers	50.00	https://neki_druzga.si	2025-01-26 16:31:40.103647+00	f	\N	\N
dafed2ba-0584-4e3a-a971-9b543eb539ed	9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	90423df2-520b-43bf-b404-f74427b5ccdd	My fourth	4th	50.00	\N	2025-01-26 16:40:10.976771+00	f	\N	\N
e7af67ef-4e9b-4d0a-b602-78b986ba1c24	dc95d1c4-9d1e-4f66-b682-b953d9eeacb2	f1f919ae-b731-43d9-93c8-42215449d531	Lopata	Neka kul lopatka	66.00	https://LOPATA.net	2025-01-27 23:01:26.831318+00	f	\N	\N
2ea20ee9-0b7e-4ede-abac-7fb8c5c74b6f	f23939ec-34e3-4470-ae83-6980445507dd	90423df2-520b-43bf-b404-f74427b5ccdd	chess board		\N	\N	2025-01-28 20:53:32.931487+00	f	\N	\N
ab4f33fc-8e03-4a7f-a7b2-d4b52758ea0c	9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	\N	Plants Gift Set	A curated collection of plants-related items perfect for birthday.	178.00	https://example.com/gift/plants	2025-01-29 21:39:42.280742+00	t	0.800	\N
9270695a-45ec-4451-b6e2-7b66dc169ff3	9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	\N	Flute Gift Set	A curated collection of flute-related items perfect for birthday.	50.00	https://example.com/gift/flute	2025-01-30 07:36:10.380954+00	t	0.517	\N
\.


                                                                                                                                                                                                       4012.dat                                                                                            0000600 0004000 0002000 00000000005 14754424544 0014250 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        \.


                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           4014.dat                                                                                            0000600 0004000 0002000 00000036032 14754424544 0014263 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        156c7dc1-3b40-4e3f-9834-ad6d9cd89e25	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-02 17:08:48.751083+00	\N	pending	\N	\N
c665d567-a194-4393-a90a-462a01d29ca6	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-02 17:10:32.207841+00	\N	pending	\N	\N
f4036969-7ecc-4336-bcd4-94b7b2b462c2	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 17:54:12.53071+00	\N	pending	\N	\N
5a929777-abce-4a1b-ad0f-9ff739e36583	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 17:57:30.15969+00	\N	pending	\N	\N
ac8621e6-e1c5-41f3-b837-50fa29e34be7	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 17:58:28.375252+00	\N	pending	\N	\N
fe76ab9a-c13c-42ce-bf60-084e1d1e70de	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 17:59:25.208265+00	\N	pending	\N	\N
1fc3e08b-6f81-41fc-8061-f9e8747afd44	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 18:03:07.683266+00	\N	pending	\N	\N
f97653c8-f0ff-459a-b181-b411982a0e67	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 18:05:25.059079+00	\N	pending	\N	\N
31e307e6-2d8c-42f3-9585-363098139d13	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 18:06:46.975233+00	\N	pending	\N	\N
7d78c5ac-90ff-470f-8d08-e02aa7c10b84	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-03 18:18:58.477845+00	\N	pending	\N	\N
eac198fa-cec8-4a7b-a1e8-c61ecf198ac3	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 14:28:58.046186+00	\N	pending	\N	\N
c417e484-a564-4d65-a26e-03cab0b988cf	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 14:37:30.023136+00	\N	pending	\N	\N
fd3c3724-2ebb-4719-b5de-cad765820f91	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 14:44:03.452004+00	\N	pending	\N	\N
d65a133b-06be-4a24-903f-f893d6972a22	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 14:46:08.524102+00	\N	pending	\N	\N
970c51fd-45df-42ad-8fa5-3ff5a760ab7b	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 14:47:02.855195+00	\N	pending	\N	\N
1386c544-ad9d-4696-afc7-eff59edf2bc0	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 14:51:48.553682+00	\N	pending	\N	\N
90e056c6-a2db-411d-af48-d29bfa84fb46	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 14:53:06.247538+00	\N	pending	\N	\N
63a29665-1186-4c47-8d12-490a055b9682	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 15:08:24.278951+00	2025-02-09 15:08:23.866+00	failed	\N	Failed to fetch
3d7da0c3-2c0c-4d03-884a-b7b5bce15687	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 15:09:21.348031+00	2025-02-09 15:09:20.997+00	failed	\N	Failed to fetch
79304172-1692-4a91-9bff-54f3a4ea4692	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 16:26:26.272335+00	\N	pending	\N	\N
33cb7c92-6f3b-40d4-8609-3a00af927333	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 16:26:29.238196+00	2025-02-09 16:26:29.009+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "38a93030-660c-4a83-9a43-68e9d2878c4e"}	\N
3fe6a14a-cefd-4824-83b5-637efe027ac8	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 17:26:29.258562+00	\N	pending	\N	\N
c1c09bfd-04a2-44f3-b444-3e6bb7f4bf7b	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 17:26:30.557388+00	2025-02-09 17:26:30.432+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "f02fcaaf-5345-4c82-abe7-a0b50ec30039"}	\N
d6db7084-8d26-4eb3-956a-8381c4b0b10a	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:24:35.742015+00	\N	pending	\N	\N
14fe379d-8153-4846-a789-e57b9f3f42a2	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:24:37.093274+00	2025-02-09 19:24:37.061+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "0adccdf3-4da4-4997-a684-3038eba485ce"}	\N
57847fa9-96d3-44ae-a621-78c13a1e8a35	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:27:18.418017+00	\N	pending	\N	\N
d1a1073f-22fd-4d25-be51-8fd0fc9e2769	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:27:19.637055+00	2025-02-09 19:27:19.587+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "83aa0697-09f8-43ac-a327-cf7dd052c59d"}	\N
7b8b37a2-c15c-4399-b5ea-c684874dcc33	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:27:42.53054+00	\N	pending	\N	\N
138d1b9b-dea4-4002-940e-9503c2d74a4c	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:27:43.839229+00	2025-02-09 19:27:43.864+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "5259df29-7867-4312-bb48-8064647292ec"}	\N
9b87569e-13aa-4170-8685-441bc6453944	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:28:26.640385+00	\N	pending	\N	\N
446b4d8a-a1ae-4179-9d92-d0eabd61078c	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:28:27.982889+00	2025-02-09 19:28:27.994+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "4cb11a24-8916-406f-bdae-d42eaf10caae"}	\N
90beb0b8-6660-42e5-8f88-c9ceb25e35d9	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:30:53.62402+00	\N	pending	\N	\N
27f5e9af-01d1-411c-87e1-7eaa776a54e4	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:30:54.873167+00	2025-02-09 19:30:54.892+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "cb00fa2f-c887-4762-aaaf-9c11fc893642"}	\N
99137188-f2b2-4df8-8c33-ccbb89993181	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:33:33.006678+00	\N	pending	\N	\N
33a062fe-ffd8-47b5-a9ba-175a23d1f872	petrodej@gmail.com	8aa662ad-6e34-41c5-ba25-e0c6acde5716	2025-02-09 19:33:34.298049+00	2025-02-09 19:33:34.328+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "3a1451ee-034b-40e6-9268-8033538dee21"}	\N
029aaa89-9d10-470d-bfdf-6629acfa5c23	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-09 19:37:53.800043+00	2025-02-09 19:37:53.849+00	failed	\N	Unknown error
a7048b17-6773-4441-8d2f-b05d5023bba1	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-09 19:38:31.41216+00	\N	pending	\N	\N
305502c0-7de0-4d2c-bf3c-74a5b780020f	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-09 19:38:32.659597+00	2025-02-09 19:38:32.703+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "fa9f9bfd-90ae-4b04-a05e-5c19c439ee69"}	\N
15f30646-573f-41a8-b815-f711280cfb4d	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-09 19:39:12.935059+00	\N	pending	\N	\N
a307e4d3-a3bf-412c-8b87-3229326b6215	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-09 19:39:14.458633+00	2025-02-09 19:39:14.519+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "0af59823-bab7-44aa-a837-de29cd173b20"}	\N
8bd41576-9e61-4e6e-acfe-da14e7535775	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-10 07:07:24.72391+00	\N	pending	\N	\N
8aaed0a1-d440-40e1-84c7-40e10a0c3a46	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-10 07:07:26.013553+00	2025-02-10 07:07:26.573+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "2c7b35cb-1928-42ca-b762-cbcac0ca0820"}	\N
bf096338-e860-4ecc-b02e-1c2d8c73784d	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-10 07:08:34.823307+00	\N	pending	\N	\N
7f5b180b-a87a-4995-8751-e62932c318e7	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-10 07:08:36.084355+00	2025-02-10 07:08:36.689+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "03222426-edd6-4b46-a6d2-1407552ff54d"}	\N
bc709095-445b-45d0-bd7d-01d0d44c24f0	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-10 07:15:29.745971+00	\N	pending	\N	\N
94a6d1ee-7d97-467e-9742-7a598cb11922	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-10 07:15:30.88703+00	2025-02-10 07:15:31.512+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "e243c8c5-93f2-4a99-ba05-fc9234141793"}	\N
b128de2c-cb04-4881-a84e-c5cc434b8d53	petrodej@gmail.com	00c20fee-e868-4195-95ce-d6aa33f1df44	2025-02-10 07:49:02.956333+00	2025-02-10 07:49:03.61+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "775f223a-d0d3-4a97-a2c2-defd86c33bb9"}	\N
8cce03f9-416d-43c6-9503-422f941eceec	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-10 07:49:54.106061+00	\N	pending	\N	\N
741efcd2-7d67-418f-a968-f603d524c75a	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-10 07:49:55.274411+00	2025-02-10 07:49:55.97+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "982a81e4-4e46-4f1c-ad87-4b2ad9366055"}	\N
cfc44776-6c2d-41b0-9e5c-bfcc02f8c6f8	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-10 16:25:32.490355+00	\N	pending	\N	\N
c9780ae6-3629-45a6-9e76-d19d7c8ff569	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-10 16:25:33.846137+00	2025-02-10 16:25:35.289+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "2f207b9f-67ae-43cf-bcc5-b376695d386c"}	\N
4d133704-0feb-4082-a862-99e5a1c771a8	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-11 07:37:41.846784+00	\N	pending	\N	\N
9e8e22de-2e65-40e0-850c-d0b34026230b	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-11 07:37:43.367772+00	2025-02-11 07:37:43.277+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "ddab3d01-af1b-4c0a-8a72-94ec0d6e4e75"}	\N
716a0121-d2ed-4d7f-ae8c-f9d6dff25624	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-12 17:54:09.754731+00	\N	pending	\N	\N
591d0f89-fb92-4e12-91ad-ee466098d4e7	petrodej@gmail.com	5758eb90-2553-478b-842e-086833112b4a	2025-02-12 17:54:11.132676+00	2025-02-12 17:54:14.832+00	sent	{"subject": "You've been invited to a Giftle project!", "email_id": "d6d054e4-524f-4303-a689-1521efba5399"}	\N
61fed1b9-3b7c-4f7d-8d69-0f4c26668219	lolek@bolek.si	5758eb90-2553-478b-842e-086833112b4a	2025-02-16 08:00:16.530074+00	\N	pending	\N	\N
603c3a62-bfae-47b4-b583-c47bcee0d71a	lolek@bolek.si	5758eb90-2553-478b-842e-086833112b4a	2025-02-16 08:00:17.472449+00	2025-02-16 08:00:19.352+00	failed	\N	You can only send testing emails to your own email address (petrodej@gmail.com). To send emails to other recipients, please verify a domain at resend.com/domains, and change the `from` address to an email using this domain.
c2bfa21e-d237-4d4a-9538-066751f397e1	22@nov.je	5758eb90-2553-478b-842e-086833112b4a	2025-02-16 09:46:19.403864+00	2025-02-16 09:46:19.403864+00	success	{"email": "22@nov.je", "action": "upsert", "user_id": "8c302e2d-3772-415d-a677-cb631878e81c", "end_time": "2025-02-16T09:46:19.403864+00:00", "function": "join_project", "start_time": "2025-02-16T09:46:19.403864+00:00", "invite_code": "0i3hXiyx"}	\N
423de54c-30ec-4b7d-97c0-0ac95b85b518	24@nov.je	5758eb90-2553-478b-842e-086833112b4a	2025-02-16 09:53:44.339159+00	2025-02-16 09:53:44.339159+00	success	{"email": "24@nov.je", "action": "upsert", "user_id": "dad6a580-e605-41b7-b425-d50384f0a3ca", "end_time": "2025-02-16T09:53:44.339159+00:00", "function": "join_project", "start_time": "2025-02-16T09:53:44.339159+00:00", "invite_code": "0i3hXiyx"}	\N
590409bd-5c4a-410a-adce-a0ddf8e1f521	ola2@join.se	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 10:03:43.201261+00	2025-02-16 10:03:43.201261+00	success	{"email": "ola2@join.se", "action": "upsert", "user_id": "4500aba9-ac1b-4405-9e81-a62e75d66cc8", "end_time": "2025-02-16T10:03:43.201261+00:00", "function": "join_project", "start_time": "2025-02-16T10:03:43.201261+00:00", "invite_code": "ToVKhVA9"}	\N
afab821c-4c41-403e-a38d-752f61496a23	ola3@lala.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 10:07:09.083767+00	2025-02-16 10:07:09.083767+00	success	{"email": "ola3@lala.si", "action": "upsert", "user_id": "8eae3dff-0102-4a9a-81f3-9e3ea1215797", "end_time": "2025-02-16T10:07:09.083767+00:00", "function": "join_project", "start_time": "2025-02-16T10:07:09.083767+00:00", "invite_code": "ToVKhVA9"}	\N
dc866d18-8cae-417a-8022-2bd70142ebf9	ojoj@a.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 10:09:43.240319+00	2025-02-16 10:09:43.240319+00	success	{"email": "ojoj@a.si", "action": "upsert", "user_id": "36e218f3-2ef7-4d0b-9994-df56c76d68cf", "end_time": "2025-02-16T10:09:43.240319+00:00", "function": "join_project", "start_time": "2025-02-16T10:09:43.240319+00:00", "invite_code": "ToVKhVA9"}	\N
7c33ae6a-eadb-4d6c-9d55-7b1a5aaeb72d	ojoj@a.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 10:09:43.420679+00	2025-02-16 10:09:43.420679+00	success	{"email": "ojoj@a.si", "action": "upsert", "user_id": "36e218f3-2ef7-4d0b-9994-df56c76d68cf", "end_time": "2025-02-16T10:09:43.420679+00:00", "function": "join_project", "start_time": "2025-02-16T10:09:43.420679+00:00", "invite_code": "ToVKhVA9"}	\N
ad72e2f1-fa53-4035-a4d0-853f7fe3548b	1@3.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 17:34:17.760512+00	2025-02-16 17:34:17.760512+00	success	{"email": "1@3.si", "action": "upsert", "user_id": "a9b51d13-d258-41cc-b903-11981f3bab69", "end_time": "2025-02-16T17:34:17.760512+00:00", "function": "join_project", "start_time": "2025-02-16T17:34:17.760512+00:00", "invite_code": "ToVKhVA9"}	\N
da87df38-f455-48a2-a84d-0d9309ab2a9b	1@3.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 17:34:18.123545+00	2025-02-16 17:34:18.123545+00	success	{"email": "1@3.si", "action": "upsert", "user_id": "a9b51d13-d258-41cc-b903-11981f3bab69", "end_time": "2025-02-16T17:34:18.123545+00:00", "function": "join_project", "start_time": "2025-02-16T17:34:18.123545+00:00", "invite_code": "ToVKhVA9"}	\N
27e3e41e-d88f-44df-a398-f616de488c1a	a@a.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 17:34:37.357271+00	2025-02-16 17:34:37.357271+00	success	{"email": "a@a.si", "action": "upsert", "user_id": "cb294aac-6a82-4d87-a901-a94a88e9e74a", "end_time": "2025-02-16T17:34:37.357271+00:00", "function": "join_project", "start_time": "2025-02-16T17:34:37.357271+00:00", "invite_code": "ToVKhVA9"}	\N
e2d2d35d-c8e4-4e6d-b679-e3d275f9cd55	a@a.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 17:34:37.5438+00	2025-02-16 17:34:37.5438+00	success	{"email": "a@a.si", "action": "upsert", "user_id": "cb294aac-6a82-4d87-a901-a94a88e9e74a", "end_time": "2025-02-16T17:34:37.5438+00:00", "function": "join_project", "start_time": "2025-02-16T17:34:37.5438+00:00", "invite_code": "ToVKhVA9"}	\N
9e907585-c179-4464-a948-97781a8a88c9	k@kak.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 17:36:13.163224+00	2025-02-16 17:36:13.163224+00	success	{"email": "k@kak.si", "action": "upsert", "user_id": "e1d3c347-e664-4187-912f-1eadca88cc92", "end_time": "2025-02-16T17:36:13.163224+00:00", "function": "join_project", "start_time": "2025-02-16T17:36:13.163224+00:00", "invite_code": "ToVKhVA9"}	\N
73f29359-0bae-4eb2-90d9-cbca5957797e	k@kak.si	1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2025-02-16 17:36:13.358671+00	2025-02-16 17:36:13.358671+00	success	{"email": "k@kak.si", "action": "upsert", "user_id": "e1d3c347-e664-4187-912f-1eadca88cc92", "end_time": "2025-02-16T17:36:13.358671+00:00", "function": "join_project", "start_time": "2025-02-16T17:36:13.358671+00:00", "invite_code": "ToVKhVA9"}	\N
\.


                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      4007.dat                                                                                            0000600 0004000 0002000 00000015074 14754424544 0014270 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        90423df2-520b-43bf-b404-f74427b5ccdd	petrodej@gmail.com	\N	\N	2025-01-26 08:56:23.739608+00	2025-01-26 08:56:23.739608+00
ee0d01af-3251-41a7-b99c-bf6ed46b3f4c	maj.osolin@gmail.com	\N	\N	2025-01-26 11:22:48.078678+00	2025-01-26 11:22:48.078678+00
aa7365db-b501-47a8-9de1-57a1584095d1	test@lala.si	\N	\N	2025-01-26 12:45:49.362742+00	2025-01-26 12:45:49.362742+00
db34dec4-63fe-4f68-859b-6f36999be1da	opala@drla.si	\N	\N	2025-01-26 14:14:07.63898+00	2025-01-26 14:14:07.63898+00
f1f919ae-b731-43d9-93c8-42215449d531	petrodej3@gmail.com	\N	\N	2025-01-27 22:59:55.02263+00	2025-01-27 22:59:55.02263+00
2c7ad380-1650-4fbc-99fa-49c4259f3b26	petrodej1@gmail.com	\N	\N	2025-02-02 15:49:32.958606+00	2025-02-02 15:49:32.958606+00
88b05c0b-f745-4346-a46d-0b56eb329e06	petrode.j@gmail.com	\N	\N	2025-02-11 07:41:59.459943+00	2025-02-11 07:41:59.459943+00
9b95ef63-b206-47ab-9f70-7721982ba2e0	novi@gmail.si	\N	\N	2025-02-11 07:45:05.734428+00	2025-02-11 07:45:05.734428+00
72fe1045-61e9-46d3-97c8-828e0917ef90	petrodej.1@gmail.com	\N	\N	2025-02-12 17:56:34.414618+00	2025-02-12 17:56:34.414618+00
8bb1d5ff-c79f-45bf-8841-eabd9cd48f32	novi2@gmail.si	\N	\N	2025-02-13 07:50:08.692775+00	2025-02-13 07:50:08.692775+00
30b99869-da9b-4cd3-b3b1-334565381b9e	en@nov.si	\N	\N	2025-02-13 07:50:56.627372+00	2025-02-13 07:50:56.627372+00
bbb83557-a695-4d8c-8ef2-5d14e15737bd	en2@nov.si	\N	\N	2025-02-13 07:53:51.446008+00	2025-02-13 07:53:51.446008+00
f33dd37b-2187-418b-aad5-ee3dff96297d	p23etrodej1@gmail.com	\N	\N	2025-02-14 05:58:47.548813+00	2025-02-14 05:58:47.548813+00
0e0120a0-5bf2-4b31-9054-bcb371e8fe67	opop@kaka.si	\N	\N	2025-02-14 06:00:26.795646+00	2025-02-14 06:00:26.795646+00
2197a9ff-a68f-4c61-867e-9d3d8f4e1a8e	kakamaka@lala.si	\N	\N	2025-02-14 06:06:50.244432+00	2025-02-14 06:06:50.244432+00
1446a92f-c1e3-42b6-abe6-7e4522a977e4	dejan@test.com	\N	\N	2025-02-14 06:07:09.667632+00	2025-02-14 06:07:09.667632+00
812a87c5-42ee-422b-b548-9ec606c98d3c	dejan1@test.com	\N	\N	2025-02-14 06:07:20.795549+00	2025-02-14 06:07:20.795549+00
e4606cb8-9368-492e-93f4-960c9b41b1db	pipi@kaka.com	\N	\N	2025-02-14 06:08:54.200622+00	2025-02-14 06:08:54.200622+00
ff48aa31-cc59-4322-b08e-dda97ed56c1f	novi@misko.si	\N	\N	2025-02-16 08:04:11.360078+00	2025-02-16 08:04:11.360078+00
7fb94dc8-4abc-49f4-a96a-cd51b46bbf6a	novi2@misko.si	\N	\N	2025-02-16 08:07:20.750617+00	2025-02-16 08:07:20.750617+00
7756a142-1dfa-4571-9db7-8af3dd80d4a7	tale@nov.je	\N	\N	2025-02-16 08:40:52.602082+00	2025-02-16 08:40:52.602082+00
88474dbe-cf40-44fc-8be1-0d65382eecc9	1tale@nov.je	\N	\N	2025-02-16 08:43:55.289646+00	2025-02-16 08:43:55.289646+00
1552117f-8002-4789-afc1-23be99b92f2d	2tale@nov.je	\N	\N	2025-02-16 08:47:53.349644+00	2025-02-16 08:47:53.349644+00
96dc11fb-acfd-4e8e-8d91-e2fe030bbbf9	3tale@nov.je	\N	\N	2025-02-16 08:56:05.22959+00	2025-02-16 08:56:05.22959+00
a94f5bae-3c07-418b-8f27-c27eb262a269	4tale@nov.je	\N	\N	2025-02-16 08:58:08.760715+00	2025-02-16 08:58:08.760715+00
ac486ea1-21e2-44e4-8f78-3427c0c645fd	5tale@nov.je	\N	\N	2025-02-16 09:01:16.724042+00	2025-02-16 09:01:16.724042+00
2cfd2c2e-df7f-4ffb-961e-f032802c4150	6tale@nov.je	\N	\N	2025-02-16 09:04:44.981171+00	2025-02-16 09:04:44.981171+00
d1072a6b-eaaf-4501-bd34-436ffafcd2f3	7tale@nov.je	\N	\N	2025-02-16 09:06:57.357616+00	2025-02-16 09:06:57.357616+00
9053aceb-fa20-46e7-b516-4c153baa6085	8tale@nov.je	\N	\N	2025-02-16 09:09:09.210128+00	2025-02-16 09:09:09.210128+00
5f903904-7dd4-4e34-8920-58313358e1da	9tale@nov.je	\N	\N	2025-02-16 09:10:52.571609+00	2025-02-16 09:10:52.571609+00
c26c43ab-2cbd-4f00-b1db-8271fec6c445	12tale@nov.je	\N	\N	2025-02-16 09:23:43.489434+00	2025-02-16 09:23:43.489434+00
c115bc96-399e-4273-981f-693419b1a758	13tale@nov.je	\N	\N	2025-02-16 09:24:23.960271+00	2025-02-16 09:24:23.960271+00
5d432299-b1e5-4886-bc27-aec2d041096e	14tale@nov.je	\N	\N	2025-02-16 09:25:55.798678+00	2025-02-16 09:25:55.798678+00
8b8db09d-3666-4e1c-8e08-306359f1f30c	15tale@nov.je	\N	\N	2025-02-16 09:27:04.153327+00	2025-02-16 09:27:04.153327+00
f73d0987-80b0-4eaf-81dd-ab7a235cc50a	17@novi.je	\N	\N	2025-02-16 09:32:55.205466+00	2025-02-16 09:32:55.205466+00
00dde8b0-1b58-488d-802c-22700bc704a4	20@nov.je	\N	\N	2025-02-16 09:40:16.652008+00	2025-02-16 09:40:16.652008+00
62a643c2-a65a-4f27-ab01-92335dcb1d91	21@nov.je	\N	\N	2025-02-16 09:42:02.065091+00	2025-02-16 09:42:02.065091+00
8c302e2d-3772-415d-a677-cb631878e81c	22@nov.je	\N	\N	2025-02-16 09:44:57.5441+00	2025-02-16 09:44:57.5441+00
d40369df-a777-4539-bb08-09e93112ea3e	23@nov.je	\N	\N	2025-02-16 09:47:50.293868+00	2025-02-16 09:47:50.293868+00
dad6a580-e605-41b7-b425-d50384f0a3ca	24@nov.je	\N	\N	2025-02-16 09:52:43.15822+00	2025-02-16 09:52:43.15822+00
ab8b48f3-d617-4024-bbf9-4ee973ff2ede	islonline.dejan@gmail.com	\N	\N	2025-02-16 09:56:10.807082+00	2025-02-16 09:56:10.807082+00
51eee9d1-145c-40d3-823c-54f395dc4739	ola@join.se	\N	\N	2025-02-16 10:00:38.665889+00	2025-02-16 10:00:38.665889+00
4500aba9-ac1b-4405-9e81-a62e75d66cc8	ola2@join.se	\N	\N	2025-02-16 10:01:41.492837+00	2025-02-16 10:01:41.492837+00
8eae3dff-0102-4a9a-81f3-9e3ea1215797	ola3@lala.si	\N	\N	2025-02-16 10:04:52.600984+00	2025-02-16 10:04:52.600984+00
36e218f3-2ef7-4d0b-9994-df56c76d68cf	ojoj@a.si	\N	\N	2025-02-16 10:08:30.636886+00	2025-02-16 10:08:30.636886+00
5213c292-68ab-47bb-a353-f7757c005767	no@dela.je	\N	\N	2025-02-16 10:10:39.997309+00	2025-02-16 10:10:39.997309+00
5f8264c9-f6b2-41c7-b2f0-d3d26b9af518	ok@a.si	\N	\N	2025-02-16 10:13:20.834985+00	2025-02-16 10:13:20.834985+00
d2cb7d57-230d-4060-9d93-0cdffec03f87	ok2@a.si	\N	\N	2025-02-16 10:13:47.557618+00	2025-02-16 10:13:47.557618+00
8009f07f-97ab-406f-b555-f8a919b4d644	u@a.si	\N	\N	2025-02-16 10:23:43.312788+00	2025-02-16 10:23:43.312788+00
412b3dbe-80b0-438b-aff8-4cd45c85b0f3	o@o.com	\N	\N	2025-02-16 11:37:16.982678+00	2025-02-16 11:37:16.982678+00
1f7e5d94-f774-4d83-a5e6-b7226c38ba6d	1o@o.com	\N	\N	2025-02-16 11:38:59.694723+00	2025-02-16 11:38:59.694723+00
349e6af7-48ea-4c65-bbdf-054201f3105c	aje@to.si	\N	\N	2025-02-16 11:41:47.544474+00	2025-02-16 11:41:47.544474+00
52f2c1ce-c62f-43e3-8878-010d745d1ece	h@h.com	\N	\N	2025-02-16 11:43:39.017946+00	2025-02-16 11:43:39.017946+00
28822ad4-e884-4988-ba9f-3850f5040e79	1@1.si	\N	\N	2025-02-16 17:29:05.175943+00	2025-02-16 17:29:05.175943+00
0a038d7a-fbd2-4922-94f1-91070f2473b3	1@2.si	\N	\N	2025-02-16 17:30:43.983557+00	2025-02-16 17:30:43.983557+00
a9b51d13-d258-41cc-b903-11981f3bab69	1@3.si	\N	\N	2025-02-16 17:31:39.308566+00	2025-02-16 17:31:39.308566+00
cb294aac-6a82-4d87-a901-a94a88e9e74a	a@a.si	\N	\N	2025-02-16 17:34:37.155421+00	2025-02-16 17:34:37.155421+00
e1d3c347-e664-4187-912f-1eadca88cc92	k@kak.si	\N	\N	2025-02-16 17:36:12.96014+00	2025-02-16 17:36:12.96014+00
\.


                                                                                                                                                                                                                                                                                                                                                                                                                                                                    4009.dat                                                                                            0000600 0004000 0002000 00000007130 14754424544 0014264 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        8aa662ad-6e34-41c5-ba25-e0c6acde5716	\N	2025-02-09 19:33:33.006678+00	member	pending	petrodej@gmail.com
8aa662ad-6e34-41c5-ba25-e0c6acde5716	2c7ad380-1650-4fbc-99fa-49c4259f3b26	2025-02-09 19:33:48.81149+00	member	active	petrodej1@gmail.com
00c20fee-e868-4195-95ce-d6aa33f1df44	2c7ad380-1650-4fbc-99fa-49c4259f3b26	2025-02-09 19:37:43.596472+00	admin	active	\N
9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	90423df2-520b-43bf-b404-f74427b5ccdd	2025-01-26 08:57:11.068268+00	admin	active	petrodej@gmail.com
9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	\N	2025-01-26 10:12:34.841067+00	member	pending	nekdo@gmail.si
9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	\N	2025-01-26 10:15:51.571571+00	member	pending	enadva@lala.com
9bca6317-b0c0-4bd9-bdc3-3ad22c81483b	\N	2025-01-26 10:15:51.571571+00	member	pending	enatri@lala.com
5c02ef68-7ac1-42e8-8387-6b2f16ba2646	90423df2-520b-43bf-b404-f74427b5ccdd	2025-01-26 10:33:33.549467+00	admin	active	\N
ee259a72-8428-4dbd-ba0e-0ff9dbec2b07	ee0d01af-3251-41a7-b99c-bf6ed46b3f4c	2025-01-26 11:25:28.437754+00	admin	active	\N
ee259a72-8428-4dbd-ba0e-0ff9dbec2b07	\N	2025-01-26 11:32:28.928766+00	member	pending	petrodej@gmail.com
dc95d1c4-9d1e-4f66-b682-b953d9eeacb2	f1f919ae-b731-43d9-93c8-42215449d531	2025-01-27 23:00:43.542763+00	admin	active	\N
dc95d1c4-9d1e-4f66-b682-b953d9eeacb2	\N	2025-01-27 23:01:46.640216+00	member	pending	ana@semrov.si
f23939ec-34e3-4470-ae83-6980445507dd	90423df2-520b-43bf-b404-f74427b5ccdd	2025-01-28 20:52:25.907656+00	admin	active	\N
f23939ec-34e3-4470-ae83-6980445507dd	\N	2025-01-28 20:54:01.437188+00	member	pending	dekisan@koder.com
7a29c5ef-9c21-4d2d-8d86-fb7368748d00	90423df2-520b-43bf-b404-f74427b5ccdd	2025-01-29 18:57:41.485872+00	admin	active	\N
3b10fd65-98af-4dec-9d86-4813b07d5d47	90423df2-520b-43bf-b404-f74427b5ccdd	2025-01-29 19:46:55.553755+00	admin	active	\N
5758eb90-2553-478b-842e-086833112b4a	2c7ad380-1650-4fbc-99fa-49c4259f3b26	2025-02-10 07:49:31.798941+00	admin	active	\N
5758eb90-2553-478b-842e-086833112b4a	\N	2025-02-14 06:00:27.034127+00	member	active	opop@kaka.si
e910db66-d8dc-4977-a41f-c6ec0aa2f021	e4606cb8-9368-492e-93f4-960c9b41b1db	2025-02-14 06:19:47.543873+00	admin	active	\N
5758eb90-2553-478b-842e-086833112b4a	\N	2025-02-16 08:00:16.530074+00	member	pending	lolek@bolek.si
5758eb90-2553-478b-842e-086833112b4a	8c302e2d-3772-415d-a677-cb631878e81c	2025-02-16 09:46:19.403864+00	member	active	22@nov.je
5758eb90-2553-478b-842e-086833112b4a	dad6a580-e605-41b7-b425-d50384f0a3ca	2025-02-16 09:53:44.339159+00	member	active	24@nov.je
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	2c7ad380-1650-4fbc-99fa-49c4259f3b26	2025-02-16 10:00:17.703726+00	admin	active	petrodej1@gmail.com
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	4500aba9-ac1b-4405-9e81-a62e75d66cc8	2025-02-16 10:03:43.201261+00	member	active	ola2@join.se
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	8eae3dff-0102-4a9a-81f3-9e3ea1215797	2025-02-16 10:07:09.083767+00	member	active	ola3@lala.si
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	36e218f3-2ef7-4d0b-9994-df56c76d68cf	2025-02-16 10:09:43.240319+00	member	active	ojoj@a.si
9da7ac8c-84d8-4b8a-8c7d-437b0e8c8ada	d2cb7d57-230d-4060-9d93-0cdffec03f87	2025-02-16 10:19:56.153883+00	admin	active	ok2@a.si
8aa662ad-6e34-41c5-ba25-e0c6acde5716	2c7ad380-1650-4fbc-99fa-49c4259f3b26	2025-02-02 15:51:31.12503+00	admin	active	\N
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	a9b51d13-d258-41cc-b903-11981f3bab69	2025-02-16 17:34:17.760512+00	member	active	1@3.si
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	cb294aac-6a82-4d87-a901-a94a88e9e74a	2025-02-16 17:34:37.357271+00	member	active	a@a.si
1cfc5ad5-584a-422b-b71c-dfd9a8d5a612	e1d3c347-e664-4187-912f-1eadca88cc92	2025-02-16 17:36:13.163224+00	member	active	k@kak.si
\.


                                                                                                                                                                                                                                                                                                                                                                                                                                        4011.dat                                                                                            0000600 0004000 0002000 00000000341 14754424544 0014252 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        e7af67ef-4e9b-4d0a-b602-78b986ba1c24	f1f919ae-b731-43d9-93c8-42215449d531	2025-01-27 23:10:44.382051+00	gold
1cb8a2a4-84a9-48dc-bf6f-ef64a833e0fa	90423df2-520b-43bf-b404-f74427b5ccdd	2025-01-30 21:09:23.320467+00	silver
\.


                                                                                                                                                                                                                                                                                               restore.sql                                                                                         0000600 0004000 0002000 00000136030 14754424544 0015404 0                                                                                                    ustar 00postgres                        postgres                        0000000 0000000                                                                                                                                                                        --
-- NOTE:
--
-- File paths need to be edited. Search for $$PATH$$ and
-- replace it with the path to the directory containing
-- the extracted data files.
--
--
-- PostgreSQL database dump
--

-- Dumped from database version 15.8
-- Dumped by pg_dump version 17.2

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

DROP DATABASE postgres;
--
-- Name: postgres; Type: DATABASE; Schema: -; Owner: postgres
--

CREATE DATABASE postgres WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8';


ALTER DATABASE postgres OWNER TO postgres;

\connect postgres

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: DATABASE postgres; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON DATABASE postgres IS 'default administrative connection database';


--
-- Name: postgres; Type: DATABASE PROPERTIES; Schema: -; Owner: postgres
--

ALTER DATABASE postgres SET "app.settings.jwt_exp" TO '3600';


\connect postgres

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pg_database_owner
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO pg_database_owner;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pg_database_owner
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- Name: member_status; Type: TYPE; Schema: public; Owner: postgres
--

CREATE TYPE public.member_status AS ENUM (
    'active',
    'pending'
);


ALTER TYPE public.member_status OWNER TO postgres;

--
-- Name: assign_random_purchaser(uuid); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.assign_random_purchaser(input_project_id uuid) RETURNS json
    LANGUAGE plpgsql SECURITY DEFINER
    AS $$
DECLARE
  selected_user_id uuid;
  result json;
BEGIN
  -- Get random active member using table alias to avoid ambiguity
  SELECT pm.user_id INTO selected_user_id
  FROM project_members pm
  WHERE pm.project_id = input_project_id
    AND pm.status = 'active'
    AND pm.user_id IS NOT NULL
  ORDER BY random()
  LIMIT 1;

  -- Update project with selected purchaser
  UPDATE gift_projects
  SET purchaser_id = selected_user_id
  WHERE id = input_project_id;

  -- Return result
  SELECT json_build_object(
    'purchaser_id', selected_user_id
  ) INTO result;

  RETURN result;
END;
$$;


ALTER FUNCTION public.assign_random_purchaser(input_project_id uuid) OWNER TO postgres;

--
-- Name: check_member_email_conflicts(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_member_email_conflicts() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  user_email text;
BEGIN
  -- If we're updating user_id and it's not null
  IF TG_OP = 'UPDATE' AND NEW.user_id IS NOT NULL THEN
    -- Get the user's email
    SELECT email INTO user_email
    FROM auth.users 
    WHERE id = NEW.user_id
    LIMIT 1;

    IF user_email IS NOT NULL THEN
      -- Update email field
      NEW.email := user_email;
    END IF;
  END IF;

  -- For both INSERT and UPDATE, check for duplicates
  IF EXISTS (
    SELECT 1 
    FROM project_members
    WHERE project_id = NEW.project_id 
    AND email = NEW.email
    AND (
      TG_OP = 'INSERT' 
      OR 
      (TG_OP = 'UPDATE' AND project_members.email != OLD.email)
    )
  ) THEN
    -- Instead of error, update the existing record
    IF TG_OP = 'INSERT' THEN
      -- Update the existing record with new data
      UPDATE project_members 
      SET 
        user_id = COALESCE(NEW.user_id, project_members.user_id),
        status = CASE 
          WHEN project_members.status = 'pending' AND NEW.status = 'active' 
          THEN 'active' 
          ELSE project_members.status 
        END
      WHERE project_id = NEW.project_id 
      AND email = NEW.email;
      
      RETURN NULL; -- Prevents the INSERT
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_member_email_conflicts() OWNER TO postgres;

--
-- Name: check_voting_allowed(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.check_voting_allowed() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM gift_projects gp
    JOIN gift_suggestions gs ON gs.project_id = gp.id
    WHERE gs.id = NEW.suggestion_id
    AND (gp.voting_closed = true OR gp.status = 'completed')
  ) THEN
    RAISE EXCEPTION 'Voting is closed for this project';
  END IF;
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.check_voting_allowed() OWNER TO postgres;

--
-- Name: generate_unique_code(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.generate_unique_code() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
  new_code text;
  code_exists boolean;
  url_safe_chars text;
BEGIN
  -- Define URL-safe characters (alphanumeric only, no special chars)
  url_safe_chars := '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  
  LOOP
    -- Generate a random 8-character code using only URL-safe characters
    new_code := '';
    FOR i IN 1..8 LOOP
      -- Random index into url_safe_chars (0-based)
      new_code := new_code || substr(
        url_safe_chars,
        floor(random() * length(url_safe_chars))::integer + 1,
        1
      );
    END LOOP;
    
    -- Check if code exists
    SELECT EXISTS (
      SELECT 1 
      FROM gift_projects 
      WHERE invite_code = new_code
    ) INTO code_exists;
    
    -- Exit loop if code is unique
    EXIT WHEN NOT code_exists;
  END LOOP;
  
  RETURN new_code;
END;
$$;


ALTER FUNCTION public.generate_unique_code() OWNER TO postgres;

--
-- Name: get_setting(text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.get_setting(setting_key text) RETURNS text
    LANGUAGE sql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
  SELECT value FROM app_settings WHERE key = setting_key;
$$;


ALTER FUNCTION public.get_setting(setting_key text) OWNER TO postgres;

--
-- Name: handle_member_updates(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.handle_member_updates() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  _user_id uuid;
  _email text;
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- When a user joins
  IF TG_OP = 'INSERT' THEN
    -- Always set email to the authenticated user's email if available
    IF _email IS NOT NULL THEN
      NEW.email := _email;
    END IF;

    -- If user is authenticated, set their user_id and make them active
    IF _user_id IS NOT NULL THEN
      NEW.user_id := _user_id;
      NEW.status := 'active';
    ELSE
      -- For email-only invites, set as pending
      NEW.status := COALESCE(NEW.status, 'pending');
    END IF;
  END IF;

  -- When updating an existing member
  IF TG_OP = 'UPDATE' THEN
    -- If user_id is being set and was previously NULL
    IF NEW.user_id IS NOT NULL AND OLD.user_id IS NULL THEN
      -- Activate the membership and ensure email matches
      NEW.status := 'active';
      -- Update email if it was a pending invitation
      IF OLD.status = 'pending' AND _email IS NOT NULL THEN
        NEW.email := _email;
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.handle_member_updates() OWNER TO postgres;

--
-- Name: join_project(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.join_project(input_project_id uuid, input_invite_code text) RETURNS void
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
DECLARE
  _user_id uuid;
  _email text;
  _log_id uuid;
  _project_exists boolean;
BEGIN
  -- Get current user info
  _user_id := auth.uid();
  _email := auth.email();

  -- Create detailed log entry
  INSERT INTO pending_notifications (
    email,
    project_id,
    status,
    metadata
  ) VALUES (
    _email,
    input_project_id,
    'debug',
    jsonb_build_object(
      'function', 'join_project',
      'user_id', _user_id,
      'email', _email,
      'invite_code', input_invite_code,
      'start_time', now()
    )
  ) RETURNING id INTO _log_id;

  -- Verify user is authenticated
  IF _user_id IS NULL OR _email IS NULL THEN
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'User must be authenticated to join project',
      processed_at = now()
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'User must be authenticated to join project';
  END IF;

  -- Check if project exists and has matching invite code
  SELECT EXISTS (
    SELECT 1 
    FROM gift_projects gp
    WHERE gp.id = input_project_id 
    AND gp.invite_code = input_invite_code
  ) INTO _project_exists;

  IF NOT _project_exists THEN
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = 'Invalid project or invite code',
      processed_at = now()
    WHERE id = _log_id;
    
    RAISE EXCEPTION 'Invalid project or invite code';
  END IF;

  -- Insert new membership, handling conflicts
  BEGIN
    -- First try to update any existing membership by email
    UPDATE project_members
    SET 
      user_id = _user_id,
      status = 'active'
    WHERE 
      project_id = input_project_id
      AND email = _email;

    -- If no rows were updated, try to update by user_id
    IF NOT FOUND THEN
      UPDATE project_members
      SET 
        email = _email,
        status = 'active'
      WHERE 
        project_id = input_project_id
        AND user_id = _user_id;
    END IF;

    -- If still no rows were updated, insert a new membership
    IF NOT FOUND THEN
      INSERT INTO project_members (
        project_id,
        email,
        user_id,
        status,
        role
      ) 
      VALUES (
        input_project_id,
        _email,
        _user_id,
        'active',
        'member'
      );
    END IF;

    -- Log success
    UPDATE pending_notifications
    SET 
      status = 'success',
      processed_at = now(),
      metadata = jsonb_build_object(
        'function', 'join_project',
        'user_id', _user_id,
        'email', _email,
        'invite_code', input_invite_code,
        'start_time', (metadata->>'start_time')::timestamptz,
        'end_time', now(),
        'action', 'upsert'
      )
    WHERE id = _log_id;

  EXCEPTION WHEN OTHERS THEN
    -- Log error details
    UPDATE pending_notifications
    SET 
      status = 'error',
      error_message = SQLERRM,
      processed_at = now(),
      metadata = jsonb_build_object(
        'function', 'join_project',
        'user_id', _user_id,
        'email', _email,
        'invite_code', input_invite_code,
        'start_time', (metadata->>'start_time')::timestamptz,
        'end_time', now(),
        'error_code', SQLSTATE,
        'error_detail', SQLERRM
      )
    WHERE id = _log_id;
    
    RAISE;
  END;
END;
$$;


ALTER FUNCTION public.join_project(input_project_id uuid, input_invite_code text) OWNER TO postgres;

--
-- Name: track_pending_notification(); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.track_pending_notification() RETURNS trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  INSERT INTO pending_notifications (email, project_id)
  VALUES (NEW.email, NEW.project_id);
  RETURN NEW;
END;
$$;


ALTER FUNCTION public.track_pending_notification() OWNER TO postgres;

--
-- Name: validate_invite_code(uuid, text); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.validate_invite_code(project_id uuid, invite_code text) RETURNS boolean
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'public'
    AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM gift_projects 
    WHERE id = project_id 
    AND invite_code = validate_invite_code.invite_code
  );
END;
$$;


ALTER FUNCTION public.validate_invite_code(project_id uuid, invite_code text) OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: app_settings; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.app_settings (
    key text NOT NULL,
    value text NOT NULL
);


ALTER TABLE public.app_settings OWNER TO postgres;

--
-- Name: gift_projects; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gift_projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    created_by uuid,
    recipient_name text NOT NULL,
    birth_date date,
    interests text[],
    created_at timestamp with time zone DEFAULT now(),
    project_date date NOT NULL,
    status text DEFAULT 'active'::text,
    selected_gift_id uuid,
    purchaser_id uuid,
    invite_code text DEFAULT encode(extensions.gen_random_bytes(6), 'base64'::text),
    parent_project_id uuid,
    is_recurring boolean DEFAULT false,
    next_occurrence_date timestamp with time zone,
    min_budget numeric(10,2),
    max_budget numeric(10,2),
    budget_type text DEFAULT 'per_person'::text,
    voting_closed boolean DEFAULT false,
    completed_at timestamp with time zone,
    CONSTRAINT gift_projects_budget_type_check CHECK ((budget_type = ANY (ARRAY['per_person'::text, 'total'::text])))
);


ALTER TABLE public.gift_projects OWNER TO postgres;

--
-- Name: gift_suggestions; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.gift_suggestions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    suggested_by uuid,
    title text NOT NULL,
    description text,
    price numeric(10,2),
    url text,
    created_at timestamp with time zone DEFAULT now(),
    is_ai_generated boolean DEFAULT false,
    confidence_score numeric(4,3),
    source_suggestion_id uuid
);


ALTER TABLE public.gift_suggestions OWNER TO postgres;

--
-- Name: pending_invitations; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pending_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid,
    email text NOT NULL,
    invite_code text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    status text DEFAULT 'pending'::text
);


ALTER TABLE public.pending_invitations OWNER TO postgres;

--
-- Name: pending_notifications; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.pending_notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email text NOT NULL,
    project_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    processed_at timestamp with time zone,
    status text DEFAULT 'pending'::text,
    metadata jsonb,
    error_message text
);


ALTER TABLE public.pending_notifications OWNER TO postgres;

--
-- Name: profiles; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.profiles (
    id uuid NOT NULL,
    email text NOT NULL,
    full_name text,
    avatar_url text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);


ALTER TABLE public.profiles OWNER TO postgres;

--
-- Name: project_members; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.project_members (
    project_id uuid NOT NULL,
    user_id uuid,
    joined_at timestamp with time zone DEFAULT now(),
    role text DEFAULT 'member'::text,
    status public.member_status DEFAULT 'active'::public.member_status NOT NULL,
    email text,
    CONSTRAINT project_members_user_or_email_check CHECK (((user_id IS NOT NULL) OR (email IS NOT NULL)))
);


ALTER TABLE public.project_members OWNER TO postgres;

--
-- Name: votes; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.votes (
    suggestion_id uuid NOT NULL,
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    medal text,
    CONSTRAINT votes_medal_check CHECK ((medal = ANY (ARRAY['gold'::text, 'silver'::text, 'bronze'::text])))
);


ALTER TABLE public.votes OWNER TO postgres;

--
-- Data for Name: app_settings; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.app_settings (key, value) FROM stdin;
\.
COPY public.app_settings (key, value) FROM '$$PATH$$/4013.dat';

--
-- Data for Name: gift_projects; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gift_projects (id, created_by, recipient_name, birth_date, interests, created_at, project_date, status, selected_gift_id, purchaser_id, invite_code, parent_project_id, is_recurring, next_occurrence_date, min_budget, max_budget, budget_type, voting_closed, completed_at) FROM stdin;
\.
COPY public.gift_projects (id, created_by, recipient_name, birth_date, interests, created_at, project_date, status, selected_gift_id, purchaser_id, invite_code, parent_project_id, is_recurring, next_occurrence_date, min_budget, max_budget, budget_type, voting_closed, completed_at) FROM '$$PATH$$/4008.dat';

--
-- Data for Name: gift_suggestions; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.gift_suggestions (id, project_id, suggested_by, title, description, price, url, created_at, is_ai_generated, confidence_score, source_suggestion_id) FROM stdin;
\.
COPY public.gift_suggestions (id, project_id, suggested_by, title, description, price, url, created_at, is_ai_generated, confidence_score, source_suggestion_id) FROM '$$PATH$$/4010.dat';

--
-- Data for Name: pending_invitations; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pending_invitations (id, project_id, email, invite_code, created_at, status) FROM stdin;
\.
COPY public.pending_invitations (id, project_id, email, invite_code, created_at, status) FROM '$$PATH$$/4012.dat';

--
-- Data for Name: pending_notifications; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.pending_notifications (id, email, project_id, created_at, processed_at, status, metadata, error_message) FROM stdin;
\.
COPY public.pending_notifications (id, email, project_id, created_at, processed_at, status, metadata, error_message) FROM '$$PATH$$/4014.dat';

--
-- Data for Name: profiles; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.profiles (id, email, full_name, avatar_url, created_at, updated_at) FROM stdin;
\.
COPY public.profiles (id, email, full_name, avatar_url, created_at, updated_at) FROM '$$PATH$$/4007.dat';

--
-- Data for Name: project_members; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.project_members (project_id, user_id, joined_at, role, status, email) FROM stdin;
\.
COPY public.project_members (project_id, user_id, joined_at, role, status, email) FROM '$$PATH$$/4009.dat';

--
-- Data for Name: votes; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.votes (suggestion_id, user_id, created_at, medal) FROM stdin;
\.
COPY public.votes (suggestion_id, user_id, created_at, medal) FROM '$$PATH$$/4011.dat';

--
-- Name: app_settings app_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.app_settings
    ADD CONSTRAINT app_settings_pkey PRIMARY KEY (key);


--
-- Name: gift_projects gift_projects_invite_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_invite_code_key UNIQUE (invite_code);


--
-- Name: gift_projects gift_projects_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_pkey PRIMARY KEY (id);


--
-- Name: gift_suggestions gift_suggestions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_pkey PRIMARY KEY (id);


--
-- Name: votes one_medal_per_user_per_suggestion; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT one_medal_per_user_per_suggestion UNIQUE (suggestion_id, user_id);


--
-- Name: pending_invitations pending_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pending_invitations
    ADD CONSTRAINT pending_invitations_pkey PRIMARY KEY (id);


--
-- Name: pending_invitations pending_invitations_project_id_email_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pending_invitations
    ADD CONSTRAINT pending_invitations_project_id_email_key UNIQUE (project_id, email);


--
-- Name: pending_notifications pending_notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pending_notifications
    ADD CONSTRAINT pending_notifications_pkey PRIMARY KEY (id);


--
-- Name: profiles profiles_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);


--
-- Name: project_members project_members_project_email_unique; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_email_unique UNIQUE (project_id, email);


--
-- Name: votes votes_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (suggestion_id, user_id);


--
-- Name: pending_invitations_email_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pending_invitations_email_idx ON public.pending_invitations USING btree (email);


--
-- Name: pending_invitations_invite_code_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX pending_invitations_invite_code_idx ON public.pending_invitations USING btree (invite_code);


--
-- Name: project_members_email_idx; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX project_members_email_idx ON public.project_members USING btree (email);


--
-- Name: project_members check_member_email_conflicts; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER check_member_email_conflicts BEFORE INSERT OR UPDATE ON public.project_members FOR EACH ROW EXECUTE FUNCTION public.check_member_email_conflicts();


--
-- Name: votes enforce_voting_allowed; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER enforce_voting_allowed BEFORE INSERT OR UPDATE ON public.votes FOR EACH ROW EXECUTE FUNCTION public.check_voting_allowed();


--
-- Name: project_members member_updates; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER member_updates BEFORE INSERT OR UPDATE ON public.project_members FOR EACH ROW EXECUTE FUNCTION public.handle_member_updates();


--
-- Name: project_members track_member_invite; Type: TRIGGER; Schema: public; Owner: postgres
--

CREATE TRIGGER track_member_invite AFTER INSERT ON public.project_members FOR EACH ROW WHEN (((new.status = 'pending'::public.member_status) AND (new.email IS NOT NULL))) EXECUTE FUNCTION public.track_pending_notification();


--
-- Name: gift_projects gift_projects_created_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.profiles(id);


--
-- Name: gift_projects gift_projects_parent_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_parent_project_id_fkey FOREIGN KEY (parent_project_id) REFERENCES public.gift_projects(id);


--
-- Name: gift_projects gift_projects_purchaser_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_projects
    ADD CONSTRAINT gift_projects_purchaser_id_fkey FOREIGN KEY (purchaser_id) REFERENCES public.profiles(id);


--
-- Name: gift_suggestions gift_suggestions_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;


--
-- Name: gift_suggestions gift_suggestions_source_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_source_suggestion_id_fkey FOREIGN KEY (source_suggestion_id) REFERENCES public.gift_suggestions(id);


--
-- Name: gift_suggestions gift_suggestions_suggested_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.gift_suggestions
    ADD CONSTRAINT gift_suggestions_suggested_by_fkey FOREIGN KEY (suggested_by) REFERENCES public.profiles(id);


--
-- Name: pending_invitations pending_invitations_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pending_invitations
    ADD CONSTRAINT pending_invitations_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;


--
-- Name: pending_notifications pending_notifications_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.pending_notifications
    ADD CONSTRAINT pending_notifications_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;


--
-- Name: profiles profiles_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.profiles
    ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--
-- Name: project_members project_members_project_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_project_id_fkey FOREIGN KEY (project_id) REFERENCES public.gift_projects(id) ON DELETE CASCADE;


--
-- Name: project_members project_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.project_members
    ADD CONSTRAINT project_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: votes votes_suggestion_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_suggestion_id_fkey FOREIGN KEY (suggestion_id) REFERENCES public.gift_suggestions(id) ON DELETE CASCADE;


--
-- Name: votes votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;


--
-- Name: gift_projects Access via invite; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Access via invite" ON public.gift_projects FOR SELECT TO authenticated, anon USING (true);


--
-- Name: gift_suggestions Add suggestions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Add suggestions" ON public.gift_suggestions FOR INSERT TO authenticated WITH CHECK (((EXISTS ( SELECT 1
   FROM (public.project_members pm
     JOIN public.gift_projects gp ON ((gp.id = pm.project_id)))
  WHERE ((pm.project_id = gift_suggestions.project_id) AND (((pm.status = 'active'::public.member_status) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email()))) OR (gp.created_by = auth.uid()))))) AND (suggested_by = auth.uid())));


--
-- Name: pending_notifications Allow authenticated users to insert notifications; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated users to insert notifications" ON public.pending_notifications FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: pending_notifications Allow authenticated users to update notifications; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated users to update notifications" ON public.pending_notifications FOR UPDATE TO authenticated USING (true) WITH CHECK (true);


--
-- Name: pending_notifications Allow authenticated users to view notifications; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow authenticated users to view notifications" ON public.pending_notifications FOR SELECT TO authenticated USING (true);


--
-- Name: app_settings Allow reading settings; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Allow reading settings" ON public.app_settings FOR SELECT TO authenticated USING (true);


--
-- Name: gift_projects Anyone can create gift projects; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Anyone can create gift projects" ON public.gift_projects FOR INSERT TO authenticated WITH CHECK (true);


--
-- Name: votes Cast votes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Cast votes" ON public.votes FOR INSERT TO authenticated WITH CHECK (((EXISTS ( SELECT 1
   FROM (public.gift_suggestions gs
     JOIN public.project_members pm ON ((pm.project_id = gs.project_id)))
  WHERE ((gs.id = votes.suggestion_id) AND (pm.user_id = auth.uid()) AND (pm.status = 'active'::public.member_status)))) AND (auth.uid() = user_id)));


--
-- Name: gift_projects Create projects; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Create projects" ON public.gift_projects FOR INSERT TO authenticated WITH CHECK ((created_by = auth.uid()));


--
-- Name: votes Delete own votes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Delete own votes" ON public.votes FOR DELETE TO authenticated USING ((auth.uid() = user_id));


--
-- Name: project_members Delete project members; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Delete project members" ON public.project_members FOR DELETE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))) OR ((email = auth.email()) OR (user_id = auth.uid()))));


--
-- Name: gift_suggestions Delete suggestions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Delete suggestions" ON public.gift_suggestions FOR DELETE TO authenticated USING (((suggested_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.gift_projects gp
  WHERE ((gp.id = gift_suggestions.project_id) AND (gp.created_by = auth.uid()))))));


--
-- Name: project_members Insert members; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert members" ON public.project_members FOR INSERT TO authenticated WITH CHECK ((((email = auth.email()) AND (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE (gift_projects.id = project_members.project_id)))) OR (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid()))))));


--
-- Name: gift_projects Insert projects; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Insert projects" ON public.gift_projects FOR INSERT TO authenticated WITH CHECK ((created_by = auth.uid()));


--
-- Name: gift_projects Manage projects; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Manage projects" ON public.gift_projects TO authenticated USING ((created_by = auth.uid())) WITH CHECK ((created_by = auth.uid()));


--
-- Name: gift_projects Members can view their projects; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Members can view their projects" ON public.gift_projects FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.project_members
  WHERE ((project_members.project_id = gift_projects.id) AND (project_members.user_id = auth.uid())))));


--
-- Name: pending_invitations Project admins can manage invitations; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Project admins can manage invitations" ON public.pending_invitations TO authenticated USING ((EXISTS ( SELECT 1
   FROM public.project_members
  WHERE ((project_members.project_id = pending_invitations.project_id) AND (project_members.user_id = auth.uid()) AND (project_members.role = 'admin'::text))))) WITH CHECK ((EXISTS ( SELECT 1
   FROM public.project_members
  WHERE ((project_members.project_id = pending_invitations.project_id) AND (project_members.user_id = auth.uid()) AND (project_members.role = 'admin'::text)))));


--
-- Name: project_members Update members; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Update members" ON public.project_members FOR UPDATE TO authenticated USING (((email = auth.email()) OR (user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))))) WITH CHECK (((email = auth.email()) OR (user_id = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid()))))));


--
-- Name: gift_suggestions Update own suggestions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Update own suggestions" ON public.gift_suggestions FOR UPDATE TO authenticated USING (((suggested_by = auth.uid()) AND (EXISTS ( SELECT 1
   FROM (public.project_members pm
     JOIN public.gift_projects gp ON ((gp.id = pm.project_id)))
  WHERE ((pm.project_id = gift_suggestions.project_id) AND (((pm.status = 'active'::public.member_status) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email()))) OR (gp.created_by = auth.uid()))))))) WITH CHECK ((suggested_by = auth.uid()));


--
-- Name: votes Update own votes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Update own votes" ON public.votes FOR UPDATE TO authenticated USING ((auth.uid() = user_id)) WITH CHECK ((auth.uid() = user_id));


--
-- Name: project_members Update project members; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Update project members" ON public.project_members FOR UPDATE TO authenticated USING (((EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))) OR ((email = auth.email()) OR (user_id = auth.uid())))) WITH CHECK (((EXISTS ( SELECT 1
   FROM public.gift_projects
  WHERE ((gift_projects.id = project_members.project_id) AND (gift_projects.created_by = auth.uid())))) OR ((email = auth.email()) OR (user_id = auth.uid()))));


--
-- Name: profiles Users can manage their own profile; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "Users can manage their own profile" ON public.profiles TO authenticated USING ((auth.uid() = id)) WITH CHECK ((auth.uid() = id));


--
-- Name: project_members View project members; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "View project members" ON public.project_members FOR SELECT TO authenticated USING (true);


--
-- Name: votes View project votes; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "View project votes" ON public.votes FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.gift_suggestions gs
     JOIN public.project_members pm ON ((pm.project_id = gs.project_id)))
  WHERE ((gs.id = votes.suggestion_id) AND (pm.user_id = auth.uid()) AND (pm.status = 'active'::public.member_status)))));


--
-- Name: gift_projects View projects; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "View projects" ON public.gift_projects FOR SELECT TO authenticated USING (((created_by = auth.uid()) OR (EXISTS ( SELECT 1
   FROM public.project_members pm
  WHERE ((pm.project_id = gift_projects.id) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email())))))));


--
-- Name: gift_suggestions View suggestions; Type: POLICY; Schema: public; Owner: postgres
--

CREATE POLICY "View suggestions" ON public.gift_suggestions FOR SELECT TO authenticated USING ((EXISTS ( SELECT 1
   FROM (public.project_members pm
     JOIN public.gift_projects gp ON ((gp.id = pm.project_id)))
  WHERE ((pm.project_id = gift_suggestions.project_id) AND (((pm.status = 'active'::public.member_status) AND ((pm.user_id = auth.uid()) OR (pm.email = auth.email()))) OR (gp.created_by = auth.uid()))))));


--
-- Name: app_settings; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;

--
-- Name: gift_projects; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.gift_projects ENABLE ROW LEVEL SECURITY;

--
-- Name: gift_suggestions; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.gift_suggestions ENABLE ROW LEVEL SECURITY;

--
-- Name: pending_invitations; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.pending_invitations ENABLE ROW LEVEL SECURITY;

--
-- Name: pending_notifications; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.pending_notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: profiles; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

--
-- Name: project_members; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.project_members ENABLE ROW LEVEL SECURITY;

--
-- Name: votes; Type: ROW SECURITY; Schema: public; Owner: postgres
--

ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;

--
-- Name: DATABASE postgres; Type: ACL; Schema: -; Owner: postgres
--

GRANT ALL ON DATABASE postgres TO dashboard_user;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pg_database_owner
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--
-- Name: FUNCTION assign_random_purchaser(input_project_id uuid); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.assign_random_purchaser(input_project_id uuid) TO anon;
GRANT ALL ON FUNCTION public.assign_random_purchaser(input_project_id uuid) TO authenticated;
GRANT ALL ON FUNCTION public.assign_random_purchaser(input_project_id uuid) TO service_role;


--
-- Name: FUNCTION check_member_email_conflicts(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_member_email_conflicts() TO anon;
GRANT ALL ON FUNCTION public.check_member_email_conflicts() TO authenticated;
GRANT ALL ON FUNCTION public.check_member_email_conflicts() TO service_role;


--
-- Name: FUNCTION check_voting_allowed(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.check_voting_allowed() TO anon;
GRANT ALL ON FUNCTION public.check_voting_allowed() TO authenticated;
GRANT ALL ON FUNCTION public.check_voting_allowed() TO service_role;


--
-- Name: FUNCTION generate_unique_code(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.generate_unique_code() TO anon;
GRANT ALL ON FUNCTION public.generate_unique_code() TO authenticated;
GRANT ALL ON FUNCTION public.generate_unique_code() TO service_role;


--
-- Name: FUNCTION get_setting(setting_key text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.get_setting(setting_key text) TO anon;
GRANT ALL ON FUNCTION public.get_setting(setting_key text) TO authenticated;
GRANT ALL ON FUNCTION public.get_setting(setting_key text) TO service_role;


--
-- Name: FUNCTION handle_member_updates(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.handle_member_updates() TO anon;
GRANT ALL ON FUNCTION public.handle_member_updates() TO authenticated;
GRANT ALL ON FUNCTION public.handle_member_updates() TO service_role;


--
-- Name: FUNCTION join_project(input_project_id uuid, input_invite_code text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.join_project(input_project_id uuid, input_invite_code text) TO anon;
GRANT ALL ON FUNCTION public.join_project(input_project_id uuid, input_invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.join_project(input_project_id uuid, input_invite_code text) TO service_role;


--
-- Name: FUNCTION track_pending_notification(); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.track_pending_notification() TO anon;
GRANT ALL ON FUNCTION public.track_pending_notification() TO authenticated;
GRANT ALL ON FUNCTION public.track_pending_notification() TO service_role;


--
-- Name: FUNCTION validate_invite_code(project_id uuid, invite_code text); Type: ACL; Schema: public; Owner: postgres
--

GRANT ALL ON FUNCTION public.validate_invite_code(project_id uuid, invite_code text) TO anon;
GRANT ALL ON FUNCTION public.validate_invite_code(project_id uuid, invite_code text) TO authenticated;
GRANT ALL ON FUNCTION public.validate_invite_code(project_id uuid, invite_code text) TO service_role;


--
-- Name: TABLE app_settings; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.app_settings TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.app_settings TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.app_settings TO service_role;


--
-- Name: TABLE gift_projects; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_projects TO service_role;
GRANT SELECT ON TABLE public.gift_projects TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_projects TO authenticated;


--
-- Name: TABLE gift_suggestions; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_suggestions TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_suggestions TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.gift_suggestions TO service_role;


--
-- Name: TABLE pending_invitations; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_invitations TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_invitations TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_invitations TO service_role;


--
-- Name: TABLE pending_notifications; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_notifications TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_notifications TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.pending_notifications TO service_role;


--
-- Name: TABLE profiles; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.profiles TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.profiles TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.profiles TO service_role;


--
-- Name: TABLE project_members; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.project_members TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.project_members TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.project_members TO service_role;


--
-- Name: TABLE votes; Type: ACL; Schema: public; Owner: postgres
--

GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.votes TO anon;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.votes TO authenticated;
GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLE public.votes TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: postgres
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO service_role;


--
-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: supabase_admin
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT SELECT,INSERT,REFERENCES,DELETE,TRIGGER,TRUNCATE,UPDATE ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        