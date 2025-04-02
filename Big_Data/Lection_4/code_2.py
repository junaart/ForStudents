index_region = D.iloc[0,0]
change = True
s = '{'
for i in range(len(D)):
    if (index_region == D.iloc[i,0]) & change:
        s += '\"region_id\":'+ D.iloc[i,0] +', \"region_name\":' + '\"'+ D.iloc[i,1]+'\", '+'\"cityes\":['
        change = False
    if index_region != D.iloc[i,0]:
        print(s[0:(len(s)-1)]+']},')
        s = '{'
        index_region = D.iloc[i,0]
        s += '\"region_id\":'+ D.iloc[i,0] +', \"region_name\":' + '\"'+ D.iloc[i,1]+'\", '+'\"cityes\":['
        change = True
    s += '{' + '\"city_id\":' + D.iloc[i,2]+', \"city_name\":'+'\"'+D.iloc[i,3]+'\"},'
