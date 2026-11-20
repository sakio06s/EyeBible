import concurrent.futures,json,subprocess
actor='00000000-0000-0000-0000-000000000004'
def sql(query):
 return subprocess.run(['docker','exec','-i','eyebible-cloud-test','psql','-U','postgres','-At','-v','ON_ERROR_STOP=1'],input=query,text=True,capture_output=True)
r=sql(f"insert into auth.users(id) values('{actor}') on conflict do nothing;delete from public.eyebible_feedback where provided_by='{actor}';")
assert r.returncode==0,r.stderr
def send(i):
 body=json.dumps({'id':f'dddddddd-0000-4000-8000-{i:012}','text':'parallel report'})
 return sql(f"set role authenticated;set request.jwt.claim.sub='{actor}';select public.feedback_action('submit','{body}'::jsonb);")
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:results=list(pool.map(send,range(6)))
assert sum(r.returncode==0 for r in results)==5,[(r.returncode,r.stderr) for r in results]
assert sum('feedback_rate_limit' in r.stderr for r in results)==1
r=sql(f"select count(*) from public.eyebible_feedback where provided_by='{actor}';")
assert r.stdout.strip()=='5',r.stdout
print('PASS concurrent support: six requests produce exactly five reports with durable per-user limit')
