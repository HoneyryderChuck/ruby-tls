require 'ffi'
require 'ffi-compiler/loader'
require 'thread'
require 'thread_safe'


module RubyTls
    module SSL
        extend FFI::Library
        if FFI::Platform.windows?
            ffi_lib 'libeay32', 'ssleay32'
        else
            ffi_lib 'ssl'
        end

        attach_function :SSL_library_init, [], :int
        attach_function :SSL_load_error_strings, [], :void
        attach_function :ERR_load_crypto_strings, [], :void


        # Common structures
        typedef :pointer, :user_data
        typedef :pointer, :bio
        typedef :pointer, :evp_key
        typedef :pointer, :evp_key_pointer
        typedef :pointer, :x509
        typedef :pointer, :x509_pointer
        typedef :pointer, :ssl
        typedef :pointer, :ssl_ctx
        typedef :int, :buffer_length
        typedef :int, :pass_length
        typedef :int, :read_write_flag


        # Multi-threaded support
        callback :locking_cb, [:int, :int, :string, :int], :void
        callback :thread_id_cb, [], :ulong
        attach_function :CRYPTO_num_locks, [], :int
        attach_function :CRYPTO_set_locking_callback, [:locking_cb], :void
        attach_function :CRYPTO_set_id_callback, [:thread_id_cb], :void


        # InitializeDefaultCredentials
        attach_function :BIO_new_mem_buf, [:string, :buffer_length], :bio
        attach_function :EVP_PKEY_free, [:evp_key], :void

        callback :pem_password_cb, [:pointer, :buffer_length, :read_write_flag, :user_data], :pass_length
        attach_function :PEM_read_bio_PrivateKey, [:bio, :evp_key_pointer, :pem_password_cb, :user_data], :evp_key

        attach_function :X509_free, [:x509], :void
        attach_function :PEM_read_bio_X509, [:bio, :x509_pointer, :pem_password_cb, :user_data], :x509

        attach_function :BIO_free, [:bio], :int

        # CONSTANTS
        SSL_ST_OK = 0x03
        attach_function :SSL_state, [:ssl], :int
        def self.SSL_is_init_finished(ssl)
            SSL_state(ssl) == SSL_ST_OK
        end

        # GetPeerCert
        attach_function :SSL_get_peer_certificate, [:ssl], :x509


        # PutPlaintext
        attach_function :SSL_write, [:ssl, :buffer_in, :buffer_length], :int
        attach_function :SSL_get_error, [:ssl, :int], :int


        # GetCiphertext
        attach_function :BIO_read, [:bio, :buffer_out, :buffer_length], :int

        # CanGetCiphertext
        attach_function :BIO_ctrl, [:bio, :int, :long, :pointer], :long
        BIO_CTRL_PENDING = 10 # opt - is their more data buffered?
        def self.BIO_pending(bio)
            BIO_ctrl(bio, BIO_CTRL_PENDING, 0, nil)
        end


        # GetPlaintext
        attach_function :SSL_accept, [:ssl], :int
        attach_function :SSL_read, [:ssl, :buffer_out, :buffer_length], :int
        attach_function :SSL_pending, [:ssl], :int

        # PutCiphertext
        attach_function :BIO_write, [:bio, :buffer_in, :buffer_length], :int

        # SelectALPNCallback
        # TODO:: SSL_select_next_proto

        # Deconstructor
        attach_function :SSL_get_shutdown, [:ssl], :int
        attach_function :SSL_shutdown, [:ssl], :int
        attach_function :SSL_clear, [:ssl], :void
        attach_function :SSL_free, [:ssl], :void


        # Constructor
        attach_function :BIO_s_mem, [], :pointer
        attach_function :BIO_new, [:pointer], :bio
        attach_function :SSL_new, [:ssl_ctx], :ssl
                                             # r,   w
        attach_function :SSL_set_bio, [:ssl, :bio, :bio], :void

        # TODO:: SSL_CTX_set_alpn_select_cb
        # Will have to put a try catch around these and support when available

        attach_function :SSL_set_ex_data, [:ssl, :int, :string], :int
        callback :verify_callback, [:int, :x509], :int
        attach_function :SSL_set_verify, [:ssl, :int, :verify_callback], :void
        attach_function :SSL_connect, [:ssl], :int

        # Verify callback
        attach_function :X509_STORE_CTX_get_current_cert, [:pointer], :x509
        attach_function :SSL_get_ex_data_X509_STORE_CTX_idx, [], :int
        attach_function :X509_STORE_CTX_get_ex_data, [:pointer, :int], :ssl
        attach_function :PEM_write_bio_X509, [:bio, :x509], :int


        # SSL Context Class
        # Constructor
        attach_function :SSLv23_server_method, [], :pointer
        attach_function :SSLv23_client_method, [], :pointer
        attach_function :SSL_CTX_new, [:pointer], :ssl_ctx

        attach_function :SSL_CTX_ctrl, [:ssl_ctx, :int, :ulong, :pointer], :long
        SSL_CTRL_OPTIONS = 32
        def self.SSL_CTX_set_options(ssl_ctx, op)
            SSL_CTX_ctrl(ssl_ctx, SSL_CTRL_OPTIONS, op, nil)
        end
        SSL_CTRL_MODE = 33
        def self.SSL_CTX_set_mode(ssl_ctx, op)
            SSL_CTX_ctrl(ssl_ctx, SSL_CTRL_MODE, op, nil)
        end
        SSL_CTRL_SET_SESS_CACHE_SIZE = 42
        def self.SSL_CTX_sess_set_cache_size(ssl_ctx, op)
            SSL_CTX_ctrl(ssl_ctx, SSL_CTRL_SET_SESS_CACHE_SIZE, op, nil)
        end

        attach_function :SSL_CTX_use_PrivateKey_file, [:ssl_ctx, :string, :int], :int
        attach_function :SSL_CTX_use_PrivateKey, [:ssl_ctx, :pointer], :int
        attach_function :ERR_print_errors_fp, [:pointer], :void     # Pointer == File Handle
        attach_function :SSL_CTX_use_certificate_chain_file, [:ssl_ctx, :string], :int
        attach_function :SSL_CTX_use_certificate, [:ssl_ctx, :x509], :int
        attach_function :SSL_CTX_set_cipher_list, [:ssl_ctx, :string], :int
        attach_function :SSL_CTX_set_session_id_context, [:ssl_ctx, :string, :buffer_length], :int

        # TODO:: SSL_CTX_set_alpn_protos


        # Deconstructor
        attach_function :SSL_CTX_free, [:ssl_ctx], :void


PrivateMaterials = <<-keystr
-----BEGIN RSA PRIVATE KEY-----
MIICXAIBAAKBgQDCYYhcw6cGRbhBVShKmbWm7UVsEoBnUf0cCh8AX+MKhMxwVDWV
Igdskntn3cSJjRtmgVJHIK0lpb/FYHQB93Ohpd9/Z18pDmovfFF9nDbFF0t39hJ/
AqSzFB3GiVPoFFZJEE1vJqh+3jzsSF5K56bZ6azz38VlZgXeSozNW5bXkQIDAQAB
AoGALA89gIFcr6BIBo8N5fL3aNHpZXjAICtGav+kTUpuxSiaym9cAeTHuAVv8Xgk
H2Wbq11uz+6JMLpkQJH/WZ7EV59DPOicXrp0Imr73F3EXBfR7t2EQDYHPMthOA1D
I9EtCzvV608Ze90hiJ7E3guGrGppZfJ+eUWCPgy8CZH1vRECQQDv67rwV/oU1aDo
6/+d5nqjeW6mWkGqTnUU96jXap8EIw6B+0cUKskwx6mHJv+tEMM2748ZY7b0yBlg
w4KDghbFAkEAz2h8PjSJG55LwqmXih1RONSgdN9hjB12LwXL1CaDh7/lkEhq0PlK
PCAUwQSdM17Sl0Xxm2CZiekTSlwmHrtqXQJAF3+8QJwtV2sRJp8u2zVe37IeH1cJ
xXeHyjTzqZ2803fnjN2iuZvzNr7noOA1/Kp+pFvUZUU5/0G2Ep8zolPUjQJAFA7k
xRdLkzIx3XeNQjwnmLlncyYPRv+qaE3FMpUu7zftuZBnVCJnvXzUxP3vPgKTlzGa
dg5XivDRfsV+okY5uQJBAMV4FesUuLQVEKb6lMs7rzZwpeGQhFDRfywJzfom2TLn
2RdJQQ3dcgnhdVDgt5o1qkmsqQh8uJrJ9SdyLIaZQIc=
-----END RSA PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIID6TCCA1KgAwIBAgIJANm4W/Tzs+s+MA0GCSqGSIb3DQEBBQUAMIGqMQswCQYD
VQQGEwJVUzERMA8GA1UECBMITmV3IFlvcmsxETAPBgNVBAcTCE5ldyBZb3JrMRYw
FAYDVQQKEw1TdGVhbWhlYXQubmV0MRQwEgYDVQQLEwtFbmdpbmVlcmluZzEdMBsG
A1UEAxMUb3BlbmNhLnN0ZWFtaGVhdC5uZXQxKDAmBgkqhkiG9w0BCQEWGWVuZ2lu
ZWVyaW5nQHN0ZWFtaGVhdC5uZXQwHhcNMDYwNTA1MTcwNjAzWhcNMjQwMjIwMTcw
NjAzWjCBqjELMAkGA1UEBhMCVVMxETAPBgNVBAgTCE5ldyBZb3JrMREwDwYDVQQH
EwhOZXcgWW9yazEWMBQGA1UEChMNU3RlYW1oZWF0Lm5ldDEUMBIGA1UECxMLRW5n
aW5lZXJpbmcxHTAbBgNVBAMTFG9wZW5jYS5zdGVhbWhlYXQubmV0MSgwJgYJKoZI
hvcNAQkBFhllbmdpbmVlcmluZ0BzdGVhbWhlYXQubmV0MIGfMA0GCSqGSIb3DQEB
AQUAA4GNADCBiQKBgQDCYYhcw6cGRbhBVShKmbWm7UVsEoBnUf0cCh8AX+MKhMxw
VDWVIgdskntn3cSJjRtmgVJHIK0lpb/FYHQB93Ohpd9/Z18pDmovfFF9nDbFF0t3
9hJ/AqSzFB3GiVPoFFZJEE1vJqh+3jzsSF5K56bZ6azz38VlZgXeSozNW5bXkQID
AQABo4IBEzCCAQ8wHQYDVR0OBBYEFPJvPd1Fcmd8o/Tm88r+NjYPICCkMIHfBgNV
HSMEgdcwgdSAFPJvPd1Fcmd8o/Tm88r+NjYPICCkoYGwpIGtMIGqMQswCQYDVQQG
EwJVUzERMA8GA1UECBMITmV3IFlvcmsxETAPBgNVBAcTCE5ldyBZb3JrMRYwFAYD
VQQKEw1TdGVhbWhlYXQubmV0MRQwEgYDVQQLEwtFbmdpbmVlcmluZzEdMBsGA1UE
AxMUb3BlbmNhLnN0ZWFtaGVhdC5uZXQxKDAmBgkqhkiG9w0BCQEWGWVuZ2luZWVy
aW5nQHN0ZWFtaGVhdC5uZXSCCQDZuFv087PrPjAMBgNVHRMEBTADAQH/MA0GCSqG
SIb3DQEBBQUAA4GBAC1CXey/4UoLgJiwcEMDxOvW74plks23090iziFIlGgcIhk0
Df6hTAs7H3MWww62ddvR8l07AWfSzSP5L6mDsbvq7EmQsmPODwb6C+i2aF3EDL8j
uw73m4YIGI0Zw2XdBpiOGkx2H56Kya6mJJe/5XORZedh1wpI7zki01tHYbcy
-----END CERTIFICATE-----
keystr


        BuiltinPasswdCB = FFI::Function.new(:int, [:pointer, :int, :int, :pointer]) do |buffer, len, flag, data|
            buffer.write_string('kittycat')
            8
        end

        CRYPTO_LOCK = 0x1
        LockingCB = FFI::Function.new(:void, [:int, :int, :string, :int]) do |mode, type, file, line|
            if (mode & CRYPTO_LOCK) != 0
                SSL_LOCKS[type].lock
            else
                # Unlock a lock
                SSL_LOCKS[type].unlock
            end
        end

        ThreadIdCB = FFI::Function.new(:ulong, []) do
            Thread.current.object_id
        end


        # INIT CODE
        @init_required ||= false
        unless @init_required
            self.SSL_load_error_strings
            self.SSL_library_init
            self.ERR_load_crypto_strings


            # Setup multi-threaded support
            SSL_LOCKS = []
            num_locks = self.CRYPTO_num_locks
            num_locks.times { SSL_LOCKS << Mutex.new }

            self.CRYPTO_set_locking_callback(LockingCB)
            self.CRYPTO_set_id_callback(ThreadIdCB)


            bio = self.BIO_new_mem_buf(PrivateMaterials, PrivateMaterials.bytesize)

            # Get the private key structure
            pointer = FFI::MemoryPointer.new(:pointer)
            self.PEM_read_bio_PrivateKey(bio, pointer, BuiltinPasswdCB, nil)
            DEFAULT_PRIVATE = pointer.get_pointer(0)

            # Get the certificate structure
            pointer = FFI::MemoryPointer.new(:pointer)
            self.PEM_read_bio_X509(bio, pointer, nil, nil)
            DEFAULT_CERT = pointer.get_pointer(0)

            self.BIO_free(bio)

            @init_required = true
        end




        #  Save RAM by releasing read and write buffers when they're empty
        SSL_MODE_RELEASE_BUFFERS = 0x00000010
        SSL_OP_ALL = 0x80000BFF
        SSL_FILETYPE_PEM = 1

        class Context
            CIPHERS = 'ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-RC4-SHA:ECDHE-RSA-AES128-SHA:AES128-GCM-SHA256:RC4:HIGH:!MD5:!aNULL:!EDH:!CAMELLIA:@STRENGTH'.freeze
            SESSION = 'ruby-tls'.freeze

            def initialize(server, options = {})
                @is_server = server
                @ssl_ctx = SSL.SSL_CTX_new(server ? SSL.SSLv23_server_method : SSL.SSLv23_client_method)
                SSL.SSL_CTX_set_options(@ssl_ctx, SSL::SSL_OP_ALL)
                SSL.SSL_CTX_set_mode(@ssl_ctx, SSL::SSL_MODE_RELEASE_BUFFERS)

                if @is_server
                    set_private_key(options[:private_key] || SSL::DEFAULT_PRIVATE)
                    set_certificate(options[:cert_chain]  || SSL::DEFAULT_CERT)
                end

                SSL.SSL_CTX_set_cipher_list(@ssl_ctx, options[:ciphers] || CIPHERS)

                if @is_server
                    SSL.SSL_CTX_sess_set_cache_size(@ssl_ctx, 128)
                    SSL.SSL_CTX_set_session_id_context(@ssl_ctx, SESSION, 8)
                else
                    set_private_key(options[:private_key])
                    set_certificate(options[:cert_chain])
                end

                # TODO:: Check for ALPN support
            end

            def cleanup
                if @ssl_ctx
                    SSL.SSL_CTX_free(@ssl_ctx)
                    @ssl_ctx = nil
                end
            end

            attr_reader :is_server
            attr_reader :ssl_ctx


            private


            def set_private_key(key)
                err = if key.is_a? FFI::Pointer
                    SSL.SSL_CTX_use_PrivateKey(@ssl_ctx, key)
                elsif key && File.file?(key)
                    SSL.SSL_CTX_use_PrivateKey_file(@ssl_ctx, key, SSL_FILETYPE_PEM)
                else
                    1
                end

                # Check for errors
                if err <= 0
                    # TODO:: ERR_print_errors_fp or ERR_print_errors
                    # So we can properly log the issue
                    cleanup
                    raise 'invalid private key or file not found'
                end
            end

            def set_certificate(cert)
                err = if cert.is_a? FFI::Pointer
                    SSL.SSL_CTX_use_certificate(@ssl_ctx, cert)
                elsif cert && File.file?(cert)
                    SSL.SSL_CTX_use_certificate_chain_file(@ssl_ctx, cert)
                else
                    1
                end

                if err <= 0
                    cleanup
                    raise 'invalid certificate or file not found'
                end
            end
        end




        class Box
            READ_BUFFER = 2048

            SSL_VERIFY_PEER = 0x01
            SSL_VERIFY_CLIENT_ONCE = 0x04
            def initialize(server, transport, options = {})
                @ready = true

                @handshake_completed = false
                @handshake_signaled = false
                @transport = transport

                @read_buffer = FFI::MemoryPointer.new(:char, READ_BUFFER, false)

                @is_server = server
                @context = Context.new(server, options)
                @bioRead = SSL.BIO_new(SSL.BIO_s_mem)
                @bioWrite = SSL.BIO_new(SSL.BIO_s_mem)
                @ssl = SSL.SSL_new(@context.ssl_ctx)
                SSL.SSL_set_bio(@ssl, @bioRead, @bioWrite)

                @write_queue = []

                # TODO:: if server && options[:alpn_string]
                # SSL_CTX_set_alpn_select_cb

                InstanceLookup[@ssl.address] = self

                if options[:verify_peer]
                    SSL.SSL_set_verify(@ssl, SSL_VERIFY_PEER | SSL_VERIFY_CLIENT_ONCE, VerifyCB)
                end

                SSL.SSL_connect(@ssl) unless server
            end


            attr_reader :is_server
            attr_reader :handshake_completed


            def get_peer_cert
                return '' unless @ready
                SSL.SSL_get_peer_certificate(@ssl)
            end

            def start
                return unless @ready

                dispatch_cipher_text
            end

            def encrypt(data)
                return unless @ready

                wrote = put_plain_text data
                if wrote < 0
                    @transport.close_cb
                else
                    dispatch_cipher_text
                end
            end

            SSL_ERROR_WANT_READ = 2
            SSL_ERROR_SSL = 1
            def decrypt(data)
                return unless @ready

                put_cipher_text data

                if not SSL.SSL_is_init_finished(@ssl)
                    resp = @is_server ? SSL.SSL_accept(@ssl) : SSL.SSL_connect(@ssl)

                    if resp < 0
                        err_code = SSL.SSL_get_error(@ssl, resp)
                        if err_code != SSL_ERROR_WANT_READ
                            @transport.close_cb if err_code == SSL_ERROR_SSL
                            return
                        end
                    end

                    @handshake_completed = true
                    signal_handshake unless @handshake_signaled
                end

                while true do
                    size = get_plain_text(@read_buffer, READ_BUFFER)
                    if size > 0
                        @transport.dispatch_cb @read_buffer.read_string(size)
                    else
                        break
                    end
                end

                dispatch_cipher_text
            end

            def signal_handshake
                @handshake_signaled = true
                @transport.handshake_cb
            end

            SSL_RECEIVED_SHUTDOWN = 2
            def cleanup
                @ready = false

                InstanceLookup.delete @ssl.address

                if (SSL.SSL_get_shutdown(@ssl) & SSL_RECEIVED_SHUTDOWN) != 0
                    SSL.SSL_shutdown @ssl
                else
                    SSL.SSL_clear @ssl
                end

                SSL.SSL_free @ssl

                @context.cleanup
            end

            # Called from class level callback function
            def verify(cert)
                @transport.verify_cb(cert) == true ? 1 : 0
            end


            private


            def get_plain_text(buffer, ready)
                # Read the buffered clear text
                size = SSL.SSL_read(@ssl, buffer, ready)
                if size >= 0
                    size
                else
                    SSL.SSL_get_error(@ssl, size) == SSL_ERROR_WANT_READ ? 0 : -1
                end
            end


            InstanceLookup = ThreadSafe::Cache.new
            VerifyCB = FFI::Function.new(:int, [:int, :pointer]) do |preverify_ok, x509_store|
                x509 = SSL.X509_STORE_CTX_get_current_cert(x509_store)
                ssl = SSL.X509_STORE_CTX_get_ex_data(x509_store, SSL.SSL_get_ex_data_X509_STORE_CTX_idx)

                bio_out = SSL.BIO_new(SSL.BIO_s_mem)
                SSL.PEM_write_bio_X509(bio_out, x509)

                len = SSL.BIO_pending(bio_out)
                buffer = FFI::MemoryPointer.new(:char, len, false)
                size = SSL.BIO_read(bio_out, buffer, len)

                # THis is the callback into the ruby class
                result = InstanceLookup[ssl.address].verify(buffer.read_string(size))

                SSL.BIO_free(bio_out)
                result
            end


            def pending_data(bio)
                SSL.BIO_pending(bio)
            end

            def get_cipher_text(buffer, length)
                SSL.BIO_read(@bioWrite, buffer, length)
            end

            def put_cipher_text(data)
                len = data.bytesize
                wrote = SSL.BIO_write(@bioRead, data, len)
                wrote == len
            end


            SSL_ERROR_WANT_WRITE = 3
            def put_plain_text(data)
                @write_queue.push(data) if data
                return 0 unless SSL.SSL_is_init_finished(@ssl)

                fatal = false
                did_work = false

                while !@write_queue.empty? do
                    data = @write_queue.pop
                    len = data.bytesize

                    wrote = SSL.SSL_write(@ssl, data, len)

                    if wrote > 0
                        did_work = true;
                    else
                        err_code = SSL.SSL_get_error(@ssl, wrote)
                        if (err_code != SSL_ERROR_WANT_READ) && (err_code != SSL_ERROR_WANT_WRITE)
                            fatal = true
                        else
                            # Not fatal - add back to the queue
                            @write_queue.unshift data
                        end

                        break
                    end
                end

                if did_work
                    1
                elsif fatal
                    -1
                else
                    0
                end
            end


            CIPHER_DISPATCH_FAILED = 'Cipher text dispatch failed'.freeze
            def dispatch_cipher_text
                begin
                    did_work = false

                    # Get all the encrypted data and transmit it
                    pending = pending_data(@bioWrite)
                    if pending > 0
                        buffer = FFI::MemoryPointer.new(:char, pending, false)

                        resp = get_cipher_text(buffer, pending)
                        raise CIPHER_DISPATCH_FAILED unless resp > 0

                        @transport.transmit_cb(buffer.read_string(resp))
                        did_work = true
                    end

                    # Send any queued out going data
                    unless @write_queue.empty?
                        resp = put_plain_text nil
                        if resp > 0
                            did_work = true
                        elsif resp < 0
                            @transport.close_cb
                        end
                    end
                end while did_work
            end
        end
    end
end
