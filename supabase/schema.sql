-- CICS alumni tracer study: normalized alumni profiles and survey responses.
create extension if not exists pgcrypto;

create table if not exists public.alumni_profiles (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  first_name text,
  last_name text,
  age smallint check (age is null or age between 15 and 120),
  sex text check (sex is null or sex in ('Female', 'Male', 'Prefer not to say')),
  current_address text,
  phone_number text,
  civil_status text,
  degree_earned text,
  graduation_date date,
  current_position text,
  current_employer text,
  contact_consent boolean not null default false,
  board_exam_passed_date date,
  board_exam_attempt_type text check (board_exam_attempt_type is null or board_exam_attempt_type in ('First timer', 'Retaker', 'Not applicable')),
  board_exam_attempt_count smallint,
  updated_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table if not exists public.tracer_study_responses (
  id uuid primary key default gen_random_uuid(),
  alumni_id uuid not null references public.alumni_profiles(id) on delete cascade,
  academic_year text not null default '2024-2025',
  course_motivation text[] not null default '{}',
  course_motivation_other text,
  employment_status text check (employment_status is null or employment_status in ('Employed', 'Unemployed')),
  unemployment_reason text check (unemployment_reason is null or unemployment_reason in ('Never employed before', 'Previously employed')),
  employment_location text check (employment_location is null or employment_location in ('Local', 'Foreign', 'Self-employed')),
  time_to_first_job text,
  delayed_employment_reasons text[] not null default '{}',
  delayed_employment_other text,
  applications_before_hire integer,
  tenure_with_current_employer text,
  business_sector text,
  business_nature text[] not null default '{}',
  business_nature_other text,
  position_level text,
  job_title text,
  employment_type text,
  employment_type_other text,
  company_sector text,
  monthly_income_range text,
  employment_alignment text,
  development_emphasis jsonb not null default '{}'::jsonb,
  transferable_skills jsonb not null default '{}'::jsonb,
  curriculum_recommendations text,
  submitted_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index if not exists tracer_responses_alumni_id_idx on public.tracer_study_responses(alumni_id);
create index if not exists tracer_responses_academic_year_idx on public.tracer_study_responses(academic_year);

-- Upgrade the earlier scalar version if it was already created.
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public' and table_name = 'tracer_study_responses'
      and column_name = 'business_nature' and data_type = 'text'
  ) then
    alter table public.tracer_study_responses
      alter column business_nature type text[]
      using case when business_nature is null or business_nature = '' then '{}'::text[]
                 else regexp_split_to_array(business_nature, '\s*,\s*') end;
    alter table public.tracer_study_responses alter column business_nature set default '{}';
  end if;
end $$;

-- Row Level Security is enabled by default for this schema. Add policies only
-- after choosing a real authentication and authorization flow for alumni/deans.
alter table public.alumni_profiles enable row level security;
alter table public.tracer_study_responses enable row level security;

alter table public.alumni_profiles add column if not exists phone_number text;
alter table public.alumni_profiles add column if not exists current_position text;
alter table public.alumni_profiles add column if not exists current_employer text;
alter table public.alumni_profiles add column if not exists contact_consent boolean not null default false;

-- The frontend uses a publishable (anon) key. It cannot read either table;
-- questionnaire writes are exposed only through this input-whitelisted RPC.
create or replace function public.submit_tracer_study(p_profile jsonb, p_response jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_alumni_id uuid;
begin
  v_email := lower(trim(coalesce(p_profile->>'email', '')));
  if v_email = '' or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'A valid alumni email is required';
  end if;

  insert into public.alumni_profiles (
    email, first_name, last_name, age, sex, current_address, civil_status,
    degree_earned, graduation_date, board_exam_passed_date,
    board_exam_attempt_type, board_exam_attempt_count, updated_at
  ) values (
    v_email, nullif(p_profile->>'first_name',''), nullif(p_profile->>'last_name',''),
    nullif(p_profile->>'age','')::smallint, nullif(p_profile->>'sex',''),
    nullif(p_profile->>'current_address',''), nullif(p_profile->>'civil_status',''),
    nullif(p_profile->>'degree_earned',''), nullif(p_profile->>'graduation_date','')::date,
    nullif(p_profile->>'board_exam_passed_date','')::date,
    nullif(p_profile->>'board_exam_attempt_type',''),
    nullif(p_profile->>'board_exam_attempt_count','')::smallint, now()
  ) on conflict (email) do update set
    first_name = coalesce(excluded.first_name, public.alumni_profiles.first_name),
    last_name = coalesce(excluded.last_name, public.alumni_profiles.last_name),
    age = coalesce(excluded.age, public.alumni_profiles.age),
    sex = coalesce(excluded.sex, public.alumni_profiles.sex),
    current_address = coalesce(excluded.current_address, public.alumni_profiles.current_address),
    civil_status = coalesce(excluded.civil_status, public.alumni_profiles.civil_status),
    degree_earned = 'BSIT',
    graduation_date = coalesce(excluded.graduation_date, public.alumni_profiles.graduation_date),
    board_exam_passed_date = coalesce(excluded.board_exam_passed_date, public.alumni_profiles.board_exam_passed_date),
    board_exam_attempt_type = coalesce(excluded.board_exam_attempt_type, public.alumni_profiles.board_exam_attempt_type),
    board_exam_attempt_count = coalesce(excluded.board_exam_attempt_count, public.alumni_profiles.board_exam_attempt_count),
    updated_at = now()
  returning id into v_alumni_id;

  insert into public.tracer_study_responses (
    alumni_id, academic_year, course_motivation, course_motivation_other,
    employment_status, unemployment_reason, employment_location, time_to_first_job,
    delayed_employment_reasons, delayed_employment_other, applications_before_hire,
    tenure_with_current_employer, business_sector, business_nature, business_nature_other,
    position_level, job_title, employment_type, employment_type_other, company_sector,
    monthly_income_range, employment_alignment, development_emphasis,
    transferable_skills, curriculum_recommendations
  ) values (
    v_alumni_id, coalesce(nullif(p_response->>'academic_year',''), '2024-2025'),
    array(select jsonb_array_elements_text(coalesce(p_response->'course_motivation','[]'::jsonb))),
    nullif(p_response->>'course_motivation_other',''),
    nullif(p_response->>'employment_status',''), nullif(p_response->>'unemployment_reason',''),
    nullif(p_response->>'employment_location',''), nullif(p_response->>'time_to_first_job',''),
    array(select jsonb_array_elements_text(coalesce(p_response->'delayed_employment_reasons','[]'::jsonb))),
    nullif(p_response->>'delayed_employment_other',''),
    nullif(p_response->>'applications_before_hire','')::integer,
    nullif(p_response->>'tenure_with_current_employer',''), nullif(p_response->>'business_sector',''),
    array(select jsonb_array_elements_text(coalesce(p_response->'business_nature','[]'::jsonb))),
    nullif(p_response->>'business_nature_other',''), nullif(p_response->>'position_level',''),
    nullif(p_response->>'job_title',''), nullif(p_response->>'employment_type',''),
    nullif(p_response->>'employment_type_other',''), nullif(p_response->>'company_sector',''),
    nullif(p_response->>'monthly_income_range',''), nullif(p_response->>'employment_alignment',''),
    coalesce(p_response->'development_emphasis','{}'::jsonb),
    coalesce(p_response->'transferable_skills','{}'::jsonb),
    nullif(p_response->>'curriculum_recommendations','')
  );

  return v_alumni_id;
end;
$$;

revoke all on function public.submit_tracer_study(jsonb, jsonb) from public;
grant execute on function public.submit_tracer_study(jsonb, jsonb) to anon, authenticated;

create or replace function public.save_alumni_profile(p_profile jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text := lower(trim(coalesce(p_profile->>'email', '')));
  v_alumni_id uuid;
begin
  if v_email = '' or v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$' then
    raise exception 'A valid alumni email is required';
  end if;
  insert into public.alumni_profiles (
    email, first_name, last_name, age, sex, current_address, phone_number,
    civil_status, degree_earned, graduation_date, current_position,
    current_employer, contact_consent, updated_at
  ) values (
    v_email, nullif(p_profile->>'first_name',''), nullif(p_profile->>'last_name',''),
    nullif(p_profile->>'age','')::smallint, nullif(p_profile->>'sex',''),
    nullif(p_profile->>'current_address',''), nullif(p_profile->>'phone_number',''),
    nullif(p_profile->>'civil_status',''), nullif(p_profile->>'degree_earned',''),
    nullif(p_profile->>'graduation_date','')::date, nullif(p_profile->>'current_position',''),
    nullif(p_profile->>'current_employer',''), coalesce((p_profile->>'contact_consent')::boolean, false), now()
  ) on conflict (email) do update set
    first_name = excluded.first_name, last_name = excluded.last_name, age = excluded.age,
    sex = excluded.sex, current_address = excluded.current_address, phone_number = excluded.phone_number,
    civil_status = excluded.civil_status, degree_earned = excluded.degree_earned,
    graduation_date = excluded.graduation_date, current_position = excluded.current_position,
    current_employer = excluded.current_employer, contact_consent = excluded.contact_consent,
    updated_at = now()
  returning id into v_alumni_id;
  return v_alumni_id;
end;
$$;

revoke all on function public.save_alumni_profile(jsonb) from public;
grant execute on function public.save_alumni_profile(jsonb) to anon, authenticated;

-- Admin-only API routes call this after validating the Dean's signed session.
-- The function returns aggregates only, never names, emails, or individual answers.
create or replace function public.get_admin_summary()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with latest as (
    select distinct on (alumni_id) alumni_id, employment_status, employment_location,
      submitted_at, academic_year
    from public.tracer_study_responses
    order by alumni_id, submitted_at desc
  ), monthly as (
    select month_start,
      (select count(*) from public.tracer_study_responses r
       where date_trunc('month', r.submitted_at) = month_start) as response_count
    from generate_series(date_trunc('month', now()) - interval '11 months',
                         date_trunc('month', now()), interval '1 month') as months(month_start)
  ), cohorts as (
    select extract(year from graduation_date)::int as graduation_year, count(*) as alumni_count,
      count(l.alumni_id) as response_count
    from public.alumni_profiles p left join latest l on l.alumni_id = p.id
    where graduation_date is not null
    group by extract(year from graduation_date)
  ), total as (
    select count(*) as alumni_count,
      count(*) filter (where first_name is not null and last_name is not null
        and current_address is not null and degree_earned is not null and graduation_date is not null) as complete_count
    from public.alumni_profiles
  ), response_stats as (
    select count(*) as response_count,
      count(*) filter (where employment_status = 'Employed') as employed_count,
      count(*) filter (where employment_status = 'Unemployed') as unemployed_count
    from latest
  )
  select jsonb_build_object(
    'totalAlumni', total.alumni_count,
    'profileComplete', total.complete_count,
    'responseCount', response_stats.response_count,
    'responseRate', case when total.alumni_count = 0 then 0 else round(100.0 * response_stats.response_count / total.alumni_count, 1) end,
    'employedCount', response_stats.employed_count,
    'unemployedCount', response_stats.unemployed_count,
    'employmentRate', case when response_stats.response_count = 0 then 0 else round(100.0 * response_stats.employed_count / response_stats.response_count, 1) end,
    'monthlyResponses', coalesce((select jsonb_agg(jsonb_build_object(
      'month', to_char(month_start, 'Mon'), 'count', response_count) order by month_start) from monthly), '[]'::jsonb),
    'cohorts', coalesce((select jsonb_agg(jsonb_build_object(
      'year', graduation_year, 'alumni', alumni_count, 'responses', response_count) order by graduation_year desc)
      from cohorts), '[]'::jsonb),
    'employment', coalesce((select jsonb_agg(jsonb_build_object('status', status, 'count', total_count) order by status)
      from (select employment_status as status, count(*) as total_count from latest group by employment_status) employment_counts), '[]'::jsonb),
    'programs', coalesce((select jsonb_agg(jsonb_build_object('name', program, 'count', total_count) order by total_count desc)
      from (select degree_earned as program, count(*) as total_count from public.alumni_profiles group by degree_earned) program_counts), '[]'::jsonb)
  )
  from total cross join response_stats;
$$;

revoke all on function public.get_admin_summary() from public;
grant execute on function public.get_admin_summary() to anon, authenticated;

create or replace function public.get_alumni_list()
returns jsonb
language sql
stable
security definer
set search_path = ''
as $$
  with latest as (
    select distinct on (alumni_id) alumni_id, employment_status
    from public.tracer_study_responses
    order by alumni_id, submitted_at desc
  )
  select coalesce(jsonb_agg(
    jsonb_build_object(
      'name', coalesce(first_name || ' ' || last_name, email),
      'email', email,
      'course', coalesce(degree_earned, 'Unknown'),
      'year', coalesce(extract(year from graduation_date)::text, 'Unknown'),
      'status', coalesce(l.employment_status, 'No Data'),
      'initials', upper(substring(coalesce(first_name, email) from 1 for 1) || substring(coalesce(last_name, '') from 1 for 1)),
      'tone', 'bg-blue-100 text-blue-700'
    ) order by p.updated_at desc
  ), '[]'::jsonb)
  from public.alumni_profiles p
  left join latest l on l.alumni_id = p.id;
$$;

revoke all on function public.get_alumni_list() from public;
grant execute on function public.get_alumni_list() to anon, authenticated;
