index_region = D.iloc[0,0]
s = '{'
s += '\"region_id\":'+ D.iloc[0,0] +', \"region_name\":' + '\"'+ D.iloc[0,1]+'\", '+'\"cities\":['
change = True
for i in range(len(D)):
    if (index_region == D.iloc[i,0]) & change:
        change = False
    if index_region != D.iloc[i,0]:
        print(s[0:(len(s)-1)]+']},')
        s = '{'
        index_region = D.iloc[i,0]
        s += '\"region_id\":'+ D.iloc[i,0] +', \"region_name\":' + '\"'+ D.iloc[i,1]+'\", '+'\"cities\":['
        change = True
    s += '{' + '\"city_id\":' + D.iloc[i,2]+', \"city_name\":'+'\"'+D.iloc[i,3]+'\"},'
