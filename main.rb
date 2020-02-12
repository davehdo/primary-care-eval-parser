require "csv"


file = File.open("report_template.rtf")
@template = file.read
@row_template = @template.match(/\_ANSWER1\_(.*\_ANSWER2\_)/m)[1]

raise "Error: must define a source file" unless ARGV.any?


def generate_template(n_questions)
  new_rows = (n_questions - 2).times.collect do |n|
    @row_template.gsub("_ANSWER2_", "_ANSWER#{n + 2}_").gsub("_QUESTION2_", "_QUESTION#{n + 2}_")
  end


  template = @template
    .gsub("_ANSWER2_", "_ANSWER#{ n_questions }_")
    .gsub("_QUESTION2_", "_QUESTION#{ n_questions }_")
    .gsub("_ANSWER1_", "_ANSWER1_#{ new_rows.join("")}")
end
  
  # rtf does not like non-ASCII chaacters
def escape(str)
  if str
    str.encode(Encoding.find("ASCII"), {invalid: :replace, undef: :replace, replce: "", universal_newline: true}) 
  else
    str
  end
end

raw = CSV.read(ARGV[0], headers: true )

# top row is the headers

# second row contains full text of questions
questions = raw[0]

# third row should be ignored

# the remainder of the rows are reviews
entries_all = raw.collect {|e| e}.slice(2,100000)


# certain columns define the type of evaluee
identifier_fields = (7..13).collect {|n| "Q#{n}"} # the trainee's name will be in one of these columns

hide_fields = ["Q6", "Q30", "Q14"]
show_fields = (questions.to_hash.keys.select {|k| k =~ /^q/i } - identifier_fields) - hide_fields


Dir.mkdir("output") unless File.exists?("output")  

# loop through each recipient
entries_all.group_by {|e| identifier_fields.collect {|n| e[n]}.compact.join("|") }
  .each do |recip, entries_for_recip|
  puts "======== #{recip}"
  
  Dir.mkdir("output/#{recip.gsub(/\W+/, "_") }") unless File.exists?("output/#{recip.gsub(/\W+/, "_") }")  
        
  
  entries_for_recip.each_with_index do |entry, i|
    # raise entry.inspect
    y,m,d = entry["RecordedDate"].split(" ")[0].split(/\-/)
    date = Date.new(y.to_i < 2000 ? (2000 + y.to_i) : y.to_i, m.to_i, d.to_i)
    output_filename = "#{recip.gsub(/\W+/, "_") }/#{"#{recip} #{ date.strftime("%F") }_n#{i}".gsub(/\W+/, "_") }"

    fields_to_write = entry.select {|k,v| show_fields.include?(k) and v}
    
    template = generate_template(fields_to_write.size)
        .gsub("_RESIDENT_NAME_", escape( recip ))
        .gsub("_ATTENDING_NAME_", escape( entry["Q30"] ))
        .gsub("_DATE_", escape( entry["RecordedDate"] ))
        .gsub("_DOMAIN_", escape( entry["Q14"] ))

    q = 1
    fields_to_write.each do |k,v|
      # puts "#{questions[k]}: #{v}"
      template.gsub!("_QUESTION#{q}_", escape( questions[k]) )
      template.gsub!("_ANSWER#{q}_", escape( v) )
      q += 1
    end
    
    File.write("output/#{output_filename}.rtf", template )
    


  end # /each entry
end

