for i in range(len(D)):
    s = "{"
    for j in range(len(list(D.columns))):
        if j != len(list(D.columns))-1:
            if j == 1:
                s += '\"'+list(D.columns)[j]+'\" : '+'\"'+str(D.iloc[i,j])+'\"'+', '
            else:
                s += '\"'+list(D.columns)[j]+'\" : '+ str(D.iloc[i,j])+', '
        else:
            s += '\"'+list(D.columns)[j]+'\" : ' + str(D.iloc[i,j])+ '},'
    print(s)
