BEGIN { RS = "===================================================================\n" ; FS = "\n" }
{
  if($0 ~ /^?.*$/) {
      print "Unknown files:"
      print $0
      next
  } else if ($1 !~ /^.*Status: Up-to-date.*$/ && $0) {
      if(match($1, /Status: (.*)/, groups) != 0) {
          printf groups[1] "\t\t"
      } else {
          print "ERR:" $1
          print $0
      }
      if(match($4, /sion:.*[0-9]*\.[0-9]*[ \t]*(\/.*),v/, groups) != 0) {
          print groups[1]
      } else {
          print "ERR:" $4
      }
 }
}
