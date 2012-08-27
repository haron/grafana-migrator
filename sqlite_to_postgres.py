#! /usr/bin/python
# SQLite3 uses 1 and 0 whereas PostgreSQL uses TRUE and FALSE for booleans
# This python script serves a single purpose of converting the sqlite dumps
# into postres-compatible dumps by converting the boolean values.

import random
import sys
import os.path

BOUNDARY = '%$#@!~R@ND0M^&*()_B0UND@RY<>?:'+str(int(random.random()*(10**10)))
COLUMNS = []
COLUMN_NAMES = ""
COLUMN_TYPES = ()

def usage():
  '''
  Print usage and exit
  '''
  print "Usage: ./bool_changer.py <filename.dump>"
  sys.exit()

def fix_column_names(first_line):
  '''
  The insert statement from sqlite3 dump is as follows:
    INSERT INTO "test" VALUES(1,'Hello');

  We need to add the column information to the statements like this:
    INSERT INTO "test" (id,name) VALUES(1,'Wibble');

  This is necessary because the column orders may be different in psql db.
  '''
  global COLUMN_NAMES
  index = first_line.index(' VALUES')
  return first_line[:index] + COLUMN_NAMES + first_line[index:]

def fix_bool(stmt):
  from_here = 'VALUES('
  start_pos = stmt.index(from_here) + len(from_here)
  cur_pos = start_pos
  newstmt = stmt[:start_pos]  #  [INSERT ... VALUES(]
  stmtlen = len(stmt)
  no_of_cols = len(COLUMN_TYPES)

  for i in range(0,no_of_cols):

    if COLUMN_TYPES[i] == 'bool':
      newstmt += stmt[start_pos:cur_pos] #nothing happens if both are same
      if stmt[cur_pos] == '1': newstmt += 'TRUE'
      elif stmt[cur_pos] == '0': newstmt += 'FALSE'
      if i == no_of_cols-1: #i.e. last column
        newstmt += ');\n'
        break
      newstmt += ','        #not last column
      cur_pos += 2
      start_pos = cur_pos
    else:
      if i == no_of_cols-1:         #if it's the last non-bool column, then
        newstmt += stmt[start_pos:] #simply insert everything that's left
        break                       #and leave

      if stmt[cur_pos] != "'":
        for cur_pos in range(cur_pos+1,stmtlen):
          if stmt[cur_pos] == ',':
            cur_pos += 1
            break #the inner loop and go to next column
      else: # the 'problematic' place. cur_pos in "'"
        cur_pos += 1 #what's next after "'"?
        while cur_pos < stmtlen:
          if stmt[cur_pos] == "'":
            if stmt[cur_pos+1] == "'": #ignore escaped quote ('')
              cur_pos += 2
              continue #searching
            elif stmt[cur_pos+1] == ",": #end of string
              cur_pos += 2
              break #to next column
          cur_pos += 1
  return newstmt

def get_psql_inserts(insert_lines):
  '''
  This method will get a list of one or more lines that together constitute
  a single insert statement from the sqlite dump, manipulates it and 
  returns the list containing the psql compatible insert statement.
  '''
  global BOUNDARY

  #First fix the column name issue.
  insert_lines[0] = fix_column_names(insert_lines[0])
  
  if 'bool' in COLUMN_TYPES:
    insert_stmt = BOUNDARY.join(insert_lines) 
    insert_stmt = fix_bool(insert_stmt)
    insert_lines = insert_stmt.split(BOUNDARY)

  return insert_lines


def process_dump(input_file,output_file):
  '''
  Process the file lazily line by line
  '''
  def process_insert(insert_lines):
    '''
    Helper method to write psql commands into output_file
    '''
    psql_inserts = get_psql_inserts(insert_lines)
    output_file.writelines(psql_inserts)

  global COLUMNS
  global COLUMN_NAMES
  global COLUMN_TYPES
  after_pragma = False     #The first few lines will be schema info upto the
                           #line that starts with "PRAGMA"
  insert_started = False   
  insert_lines = []
  insert_stmt_start = 'INSERT'

  for line in input_file:
    #Get the schema info from the head of the dump file
    if not after_pragma:
      if line[0].isdigit():
        COLUMNS.append(tuple(line.split('|')[1:3]))
      elif line.startswith('PRAGMA'):
        after_pragma = True
        COLUMN_NAMES = str(tuple([name for name,datatype in COLUMNS]))
        COLUMN_TYPES = tuple([datatype for name,datatype in COLUMNS])
        #Python uses single quotes for enclosing a string.
        #But psql uses double quotes on "column names" and
        #single quotes on strings inside VALUES(..)
        COLUMN_NAMES = ' ' + COLUMN_NAMES.replace("'",'"') 
      continue

    #Ignore the lines from PRAGMA and before INSERT. 
    if not insert_started:
      if line.startswith('CREATE TABLE'):
        table_name = line[line.index('"'):]
        table_name = table_name[:table_name.index('"',1)+1] # '"table_name"'
        insert_stmt_start = 'INSERT INTO ' + table_name
      elif line.startswith('INSERT'): 
        insert_started = True
      else: continue
      
    #If the control reaches here, it must mean that the first insert statement
    #has appeared. But the insert statements may span multiple lines. So, we
    #collect those lines and process them.

    if line.startswith(insert_stmt_start):
      if insert_lines:               #True from 2nd insert statement
        process_insert(insert_lines) #Insert the previous insert statement
      insert_lines = [line]          #and append the current one
    elif insert_lines: 
      insert_lines.append(line)

  if not insert_lines: return
  while insert_lines[-1].endswith(';\n') and \
        (insert_lines[-1].startswith('CREATE INDEX') or \
         insert_lines[-1].startswith('COMMIT')):
    insert_lines.pop()    #remove the create index and commit lines at the end
  process_insert(insert_lines) #fix the last insert statement

      

  
if __name__ == '__main__':
  if len(sys.argv) != 2:
    usage()
  
  filename = sys.argv[1]
  output_filename = filename + '.psql'
  
  if not os.path.isfile(filename):
    print "FATAL: Not a valid filename"
    usage()

  print sys.argv[0], ': Trying to convert', sys.argv[1]
  try:
    input_file = open(filename,'r')
    output_file = open(output_filename,'w')
    process_dump(input_file,output_file)
  finally:
    input_file.close()
    output_file.close()
  print sys.argv[0], ': Converted to', output_filename
  print