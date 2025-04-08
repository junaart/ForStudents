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
