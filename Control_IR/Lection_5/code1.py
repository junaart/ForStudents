#Функция реализует запрос на чтение к базе данных
def query_sql (db, query, visible = True):
  import sqlite3
  sqlite_connection = sqlite3.connect(db)
  cursor = sqlite_connection.cursor()
  cursor.execute(query)
  sqlite_connection.commit()
  if visible:
    rows = cursor.fetchall()
    names = tuple(map(lambda x: x[0], cursor.description))
    import pandas as pd
    import numpy as np
    aa=np.array(rows)
    dd=pd.DataFrame(aa, columns=names)
  cursor.close()
  sqlite_connection.close()
  if visible:
    return dd


D = query_sql('nanoedu.db', '''
SELECT sp_region.id as region_id, sp_region.name as region_name, 
       sp_city.id as city_id, sp_city.name as city_name FROM sp_region,sp_city 
where sp_region.id = sp_city.sp_region_id order by region_id
'''
)

index_region = D.iloc[0,0]
s = '{'
s += '\"_id\":'+ D.iloc[0,0] +', \"region_name\":' + '\"'+ D.iloc[0,1]+'\", '+'\"cities\":['
change = True
for i in range(len(D)):
    if (index_region == D.iloc[i,0]) & change:
        change = False
    if index_region != D.iloc[i,0]:
        print(s[0:(len(s)-1)]+']},')
        s = '{'
        index_region = D.iloc[i,0]
        s += '\"_id\":'+ D.iloc[i,0] +', \"region_name\":' + '\"'+ D.iloc[i,1]+'\", '+'\"cities\":['
        change = True
    s += '\"'+D.iloc[i,3]+'\",' 
