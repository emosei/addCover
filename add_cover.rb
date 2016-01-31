require "prawn"
require 'fastimage'
require 'fileutils'

# result : [ filetype, result ]
#   filetype ::= ( :gif, :jpg, :png, :unknown )
#   result   ::= ( :damaged, :clean )
def check_file(filename)
    result = [ :unknown, :clean ]
    File.open(filename, "rb") do |f|
        begin
            header = f.read(8)
            f.seek(-12, IO::SEEK_END)
            footer = f.read(12)
            rescue
            result[1] = :damaged
            return result
        end
        
        if header[0,2].unpack("H*") == [ "ffd8" ]
            result[0] = :jpg
            result[1] = :damaged unless footer[-2,2].unpack("H*") == [ "ffd9" ]
        end
    end
    return (result[0] == :jpg && result[1] == :clean)
end

list = []

Dir.glob( File.join(ARGV[0], '/**/*') ).each do |file|
  next unless File.extname(file) == '.pdf'
  list << file
end

total = list.size

# 出力ファイルのチェック
#save_dir_name = 'output'
#save_dir = File.join(File::cwd, save_dir_name)
#FileUtils.mkdir_p(save_dir) unless FileTest.exist?(save_dir)

cnt = 0;

list.each do |file|
  cnt += 1
  puts "#{cnt}/#{total} : #{file}"
  dir, file_name = File::split(file)
  next if file =~ /_(.*).1.pdf/
  # ISBNからカバー画像ファイル取得
  next unless file =~ /_(.*).pdf/
  image_name = "#{$1}.09.LZZZZZZZ.jpg"
  `wget http://images-jp.amazon.com/images/P/#{image_name}`

  result = check_file(image_name)
  puts "#{image_name} is check = [#{result}]"
  next unless result
  # カバー画像のみのPDFを生成
  Prawn::Document.generate('cover.pdf', :page_size => FastImage.size(image_name)) do |pdf|
    pdf.image image_name, :position => :center, :vposition => :center
                        
    # 見開きが崩れないように空白ページを差し込み
    pdf.start_new_page
  end

  # :page_sizeを指定すると1p目に空白ページが入ってしまうので消す
  `pdftk cover.pdf cat 2-end output cover2.pdf`

  # 元のPDFファイルと結合
  save_file_path = File.join(dir, "#{File::basename(file_name, '.pdf')}.1.pdf")
  `pdftk cover2.pdf "#{file}" cat output "#{save_file_path}"`

  # 後処理
  `rm cover.pdf cover2.pdf #{image_name} "#{file}"`
  
end

