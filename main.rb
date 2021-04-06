# frozen_string_literal: true

MATRIX_H = [[0, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 0, 0, 0, 0, 0],
            [1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0],
            [0, 1, 0, 1, 0, 0, 1, 1, 0, 0, 1, 0, 0, 0, 0, 0],
            [1, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 0],
            [1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0],
            [0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0],
            [0, 0, 1, 1, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0],
            [1, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 1]].freeze

BITS_IN_BYTE = 8
UNASSIGNED = -1

def false.to_i
  0
end

def true.to_i
  1
end

def encode(file_to_encode)

  unless File.exist? file_to_encode
    raise StandardError, "File #{file_to_encode} not found"
  end

  binary_file = File.open file_to_encode, 'rb'
  encoded_message = File.open("encoded_#{file_to_encode}", 'wb')
  parity_bits = Array.new(BITS_IN_BYTE, 0)

  binary_file.each_char do |char|

    # reset parity bits
    parity_bits.each_index { |i| parity_bits[i] = 0 }

    # convert char to array of 0 and 1
    data_bits = char.unpack('B*')[0].split('').map(&:to_i)

    # generate parity bits
    (0..7).each do |parity_bit|
      (0..7).each do |data_bit|
        parity_bits[parity_bit] += data_bits[data_bit] * MATRIX_H[parity_bit][data_bit]
      end
      parity_bits[parity_bit] %= 2
    end

    # output to file
    encoded_message.putc bit_array_to_int data_bits
    encoded_message.putc bit_array_to_int parity_bits
  end

  encoded_message.close
  puts "File encoded correctly\n"
end

def fix_errors(encoded_message, error_array)
  is_single_error = true

  # check mistake number
  column_one = 0
  while column_one < (BITS_IN_BYTE * 2) - 1
    column_two = column_one + 1
    while column_two < BITS_IN_BYTE * 2
      is_single_error = false
      (0..BITS_IN_BYTE - 1).each do |row|
        if error_array[row] != (MATRIX_H[row][column_one] ^ MATRIX_H[row][column_two])
          is_single_error = true
          break
        end
      end

      # if two errors
      unless is_single_error
        first_error_index = column_one
        second_error_index = column_two

        # fix double error
        encoded_message[first_error_index] = (encoded_message[first_error_index] + 1) % 2
        encoded_message[second_error_index] = (encoded_message[second_error_index] + 1) % 2
        column_one = BITS_IN_BYTE * 2
        break
      end
      column_two += 1
    end
    column_one += 1
  end

  if is_single_error
    (0..BITS_IN_BYTE * 2 - 1).each do |i|
      (0..BITS_IN_BYTE - 1).each do |j|
        break if MATRIX_H[j][i] != error_array[j]

        next unless j == BITS_IN_BYTE - 1

        # fix single error
        encoded_message[i] = (encoded_message[i] + 1) % 2
        i = BITS_IN_BYTE * 2
      end
    end
  end
end

def decode(encoded_file_name)

  unless File.exist? encoded_file_name
    raise StandardError, "File #{encoded_file_name} not found"
  end

  decoded_file = File.open("decoded#{encoded_file_name.delete_prefix('encoded')}", 'w')
  encoded_file = File.open(encoded_file_name, 'rb')
  binary_encoded_message = [] # T matrix
  error_array = Array.new(BITS_IN_BYTE, 0) # E matrix
  error_occurred = false
  it = 0

  while (char = encoded_file.getc) # while not EOF
    it += 1
    if it <= 2
      char.unpack('B*')[0].split('').map(&:to_i).each { |bit| binary_encoded_message.push bit }
    end

    next unless it == 2

    it = 0

    # reset error_array
    error_array.each_index { |i| error_array[i] = 0 }

    # check parity bits
    (0..BITS_IN_BYTE - 1).each do |j|
      (0..BITS_IN_BYTE * 2 - 1).each do |i|
        error_array[j] += binary_encoded_message[i] * MATRIX_H[j][i]
      end
      error_array[j] %= 2

      # if product of T and H is not 0 error occurred
      error_occurred = true if error_array[j] == 1
    end

    fix_errors(binary_encoded_message, error_array) if error_occurred
    error_occurred = false

    # write to file
    decoded_file.putc bit_array_to_int binary_encoded_message[0, BITS_IN_BYTE]

    binary_encoded_message = []
  end

  decoded_file.close
  encoded_file.close
  puts "File decoded correctly\n"

end

def bit_array_to_int(bit_array)
  power_of_two = 2.pow(bit_array.length - 1)
  value = 0
  (0..bit_array.length - 1).each do |i|
    value += power_of_two * bit_array[i]
    power_of_two /= 2
  end
  value
end

loop do
  puts "[1]Encode\n[2]Decode\n[3]Exit\nChoice:"
  user_choice = gets.chomp

  case user_choice
  when '1'
    puts 'Encoding: enter filename with extension (only source directory): '
    file_to_encode = gets.chomp
    begin
      encode file_to_encode
    rescue StandardError => e
      puts e
    end
  when '2'
    puts 'Decoding: enter filename with extension (only source directory): '
    file_to_decode = gets.chomp
    begin
      decode(file_to_decode)
    rescue StandardError => e
      puts e
    end
  when '3'
    exit
  else
    puts 'Wrong input'
  end
end
