create index if not exists knowledge_search_idx on public.knowledge_articles using gin (to_tsvector('english',coalesce(title,'') || ' ' || coalesce(body,'')));
create function public.search_verified_knowledge(query_text text)
returns table(title text,body text,source_name text,source_url text)
language sql stable security invoker set search_path=public,pg_temp as $$
  with terms as (select to_tsquery('english',coalesce(string_agg(quote_literal(word),' | '),'')) as query from unnest(tsvector_to_array(to_tsvector('english',left(query_text,2000)))) word)
  select k.title,k.body,k.source_name,k.source_url from public.knowledge_articles k cross join terms
  where k.verified and k.published and to_tsvector('english',coalesce(k.title,'') || ' ' || coalesce(k.body,'')) @@ terms.query
  order by ts_rank(to_tsvector('english',coalesce(k.title,'') || ' ' || coalesce(k.body,'')), terms.query) desc
  limit 8
$$;
