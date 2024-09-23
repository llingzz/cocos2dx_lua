// Generated by the protocol buffer compiler.  DO NOT EDIT!
// source: pb_common.proto

#include "pb_common.pb.h"

#include <algorithm>
#include "google/protobuf/io/coded_stream.h"
#include "google/protobuf/extension_set.h"
#include "google/protobuf/wire_format_lite.h"
#include "google/protobuf/descriptor.h"
#include "google/protobuf/generated_message_reflection.h"
#include "google/protobuf/reflection_ops.h"
#include "google/protobuf/wire_format.h"
#include "google/protobuf/generated_message_tctable_impl.h"
// @@protoc_insertion_point(includes)

// Must be included last.
#include "google/protobuf/port_def.inc"
PROTOBUF_PRAGMA_INIT_SEG
namespace _pb = ::google::protobuf;
namespace _pbi = ::google::protobuf::internal;
namespace _fl = ::google::protobuf::internal::field_layout;
namespace pb_common {

inline constexpr req_test::Impl_::Impl_(
    ::_pbi::ConstantInitialized) noexcept
      : _cached_size_{0},
        n1_{0} {}

template <typename>
PROTOBUF_CONSTEXPR req_test::req_test(::_pbi::ConstantInitialized)
    : _impl_(::_pbi::ConstantInitialized()) {}
struct req_testDefaultTypeInternal {
  PROTOBUF_CONSTEXPR req_testDefaultTypeInternal() : _instance(::_pbi::ConstantInitialized{}) {}
  ~req_testDefaultTypeInternal() {}
  union {
    req_test _instance;
  };
};

PROTOBUF_ATTRIBUTE_NO_DESTROY PROTOBUF_CONSTINIT
    PROTOBUF_ATTRIBUTE_INIT_PRIORITY1 req_testDefaultTypeInternal _req_test_default_instance_;

inline constexpr req_head::Impl_::Impl_(
    ::_pbi::ConstantInitialized) noexcept
      : _cached_size_{0},
        protocol_code_{0},
        data_len_{0} {}

template <typename>
PROTOBUF_CONSTEXPR req_head::req_head(::_pbi::ConstantInitialized)
    : _impl_(::_pbi::ConstantInitialized()) {}
struct req_headDefaultTypeInternal {
  PROTOBUF_CONSTEXPR req_headDefaultTypeInternal() : _instance(::_pbi::ConstantInitialized{}) {}
  ~req_headDefaultTypeInternal() {}
  union {
    req_head _instance;
  };
};

PROTOBUF_ATTRIBUTE_NO_DESTROY PROTOBUF_CONSTINIT
    PROTOBUF_ATTRIBUTE_INIT_PRIORITY1 req_headDefaultTypeInternal _req_head_default_instance_;
}  // namespace pb_common
static ::_pb::Metadata file_level_metadata_pb_5fcommon_2eproto[2];
static constexpr const ::_pb::EnumDescriptor**
    file_level_enum_descriptors_pb_5fcommon_2eproto = nullptr;
static constexpr const ::_pb::ServiceDescriptor**
    file_level_service_descriptors_pb_5fcommon_2eproto = nullptr;
const ::uint32_t TableStruct_pb_5fcommon_2eproto::offsets[] PROTOBUF_SECTION_VARIABLE(
    protodesc_cold) = {
    PROTOBUF_FIELD_OFFSET(::pb_common::req_head, _impl_._has_bits_),
    PROTOBUF_FIELD_OFFSET(::pb_common::req_head, _internal_metadata_),
    ~0u,  // no _extensions_
    ~0u,  // no _oneof_case_
    ~0u,  // no _weak_field_map_
    ~0u,  // no _inlined_string_donated_
    ~0u,  // no _split_
    ~0u,  // no sizeof(Split)
    PROTOBUF_FIELD_OFFSET(::pb_common::req_head, _impl_.protocol_code_),
    PROTOBUF_FIELD_OFFSET(::pb_common::req_head, _impl_.data_len_),
    0,
    1,
    PROTOBUF_FIELD_OFFSET(::pb_common::req_test, _impl_._has_bits_),
    PROTOBUF_FIELD_OFFSET(::pb_common::req_test, _internal_metadata_),
    ~0u,  // no _extensions_
    ~0u,  // no _oneof_case_
    ~0u,  // no _weak_field_map_
    ~0u,  // no _inlined_string_donated_
    ~0u,  // no _split_
    ~0u,  // no sizeof(Split)
    PROTOBUF_FIELD_OFFSET(::pb_common::req_test, _impl_.n1_),
    0,
};

static const ::_pbi::MigrationSchema
    schemas[] PROTOBUF_SECTION_VARIABLE(protodesc_cold) = {
        {0, 10, -1, sizeof(::pb_common::req_head)},
        {12, 21, -1, sizeof(::pb_common::req_test)},
};

static const ::_pb::Message* const file_default_instances[] = {
    &::pb_common::_req_head_default_instance_._instance,
    &::pb_common::_req_test_default_instance_._instance,
};
const char descriptor_table_protodef_pb_5fcommon_2eproto[] PROTOBUF_SECTION_VARIABLE(protodesc_cold) = {
    "\n\017pb_common.proto\022\tpb_common\"3\n\010req_head"
    "\022\025\n\rprotocol_code\030\001 \001(\005\022\020\n\010data_len\030\002 \001("
    "\005\"\026\n\010req_test\022\n\n\002n1\030\001 \001(\005"
};
static ::absl::once_flag descriptor_table_pb_5fcommon_2eproto_once;
const ::_pbi::DescriptorTable descriptor_table_pb_5fcommon_2eproto = {
    false,
    false,
    105,
    descriptor_table_protodef_pb_5fcommon_2eproto,
    "pb_common.proto",
    &descriptor_table_pb_5fcommon_2eproto_once,
    nullptr,
    0,
    2,
    schemas,
    file_default_instances,
    TableStruct_pb_5fcommon_2eproto::offsets,
    file_level_metadata_pb_5fcommon_2eproto,
    file_level_enum_descriptors_pb_5fcommon_2eproto,
    file_level_service_descriptors_pb_5fcommon_2eproto,
};

// This function exists to be marked as weak.
// It can significantly speed up compilation by breaking up LLVM's SCC
// in the .pb.cc translation units. Large translation units see a
// reduction of more than 35% of walltime for optimized builds. Without
// the weak attribute all the messages in the file, including all the
// vtables and everything they use become part of the same SCC through
// a cycle like:
// GetMetadata -> descriptor table -> default instances ->
//   vtables -> GetMetadata
// By adding a weak function here we break the connection from the
// individual vtables back into the descriptor table.
PROTOBUF_ATTRIBUTE_WEAK const ::_pbi::DescriptorTable* descriptor_table_pb_5fcommon_2eproto_getter() {
  return &descriptor_table_pb_5fcommon_2eproto;
}
// Force running AddDescriptors() at dynamic initialization time.
PROTOBUF_ATTRIBUTE_INIT_PRIORITY2
static ::_pbi::AddDescriptorsRunner dynamic_init_dummy_pb_5fcommon_2eproto(&descriptor_table_pb_5fcommon_2eproto);
namespace pb_common {
// ===================================================================

class req_head::_Internal {
 public:
  using HasBits = decltype(std::declval<req_head>()._impl_._has_bits_);
  static constexpr ::int32_t kHasBitsOffset =
    8 * PROTOBUF_FIELD_OFFSET(req_head, _impl_._has_bits_);
  static void set_has_protocol_code(HasBits* has_bits) {
    (*has_bits)[0] |= 1u;
  }
  static void set_has_data_len(HasBits* has_bits) {
    (*has_bits)[0] |= 2u;
  }
};

req_head::req_head(::google::protobuf::Arena* arena)
    : ::google::protobuf::Message(arena) {
  SharedCtor(arena);
  // @@protoc_insertion_point(arena_constructor:pb_common.req_head)
}
req_head::req_head(
    ::google::protobuf::Arena* arena, const req_head& from)
    : req_head(arena) {
  MergeFrom(from);
}
inline PROTOBUF_NDEBUG_INLINE req_head::Impl_::Impl_(
    ::google::protobuf::internal::InternalVisibility visibility,
    ::google::protobuf::Arena* arena)
      : _cached_size_{0} {}

inline void req_head::SharedCtor(::_pb::Arena* arena) {
  new (&_impl_) Impl_(internal_visibility(), arena);
  ::memset(reinterpret_cast<char *>(&_impl_) +
               offsetof(Impl_, protocol_code_),
           0,
           offsetof(Impl_, data_len_) -
               offsetof(Impl_, protocol_code_) +
               sizeof(Impl_::data_len_));
}
req_head::~req_head() {
  // @@protoc_insertion_point(destructor:pb_common.req_head)
  _internal_metadata_.Delete<::google::protobuf::UnknownFieldSet>();
  SharedDtor();
}
inline void req_head::SharedDtor() {
  ABSL_DCHECK(GetArena() == nullptr);
  _impl_.~Impl_();
}

PROTOBUF_NOINLINE void req_head::Clear() {
// @@protoc_insertion_point(message_clear_start:pb_common.req_head)
  PROTOBUF_TSAN_WRITE(&_impl_._tsan_detect_race);
  ::uint32_t cached_has_bits = 0;
  // Prevent compiler warnings about cached_has_bits being unused
  (void) cached_has_bits;

  cached_has_bits = _impl_._has_bits_[0];
  if (cached_has_bits & 0x00000003u) {
    ::memset(&_impl_.protocol_code_, 0, static_cast<::size_t>(
        reinterpret_cast<char*>(&_impl_.data_len_) -
        reinterpret_cast<char*>(&_impl_.protocol_code_)) + sizeof(_impl_.data_len_));
  }
  _impl_._has_bits_.Clear();
  _internal_metadata_.Clear<::google::protobuf::UnknownFieldSet>();
}

const char* req_head::_InternalParse(
    const char* ptr, ::_pbi::ParseContext* ctx) {
  ptr = ::_pbi::TcParser::ParseLoop(this, ptr, ctx, &_table_.header);
  return ptr;
}


PROTOBUF_CONSTINIT PROTOBUF_ATTRIBUTE_INIT_PRIORITY1
const ::_pbi::TcParseTable<1, 2, 0, 0, 2> req_head::_table_ = {
  {
    PROTOBUF_FIELD_OFFSET(req_head, _impl_._has_bits_),
    0, // no _extensions_
    2, 8,  // max_field_number, fast_idx_mask
    offsetof(decltype(_table_), field_lookup_table),
    4294967292,  // skipmap
    offsetof(decltype(_table_), field_entries),
    2,  // num_field_entries
    0,  // num_aux_entries
    offsetof(decltype(_table_), field_names),  // no aux_entries
    &_req_head_default_instance_._instance,
    ::_pbi::TcParser::GenericFallback,  // fallback
  }, {{
    // optional int32 data_len = 2;
    {::_pbi::TcParser::SingularVarintNoZag1<::uint32_t, offsetof(req_head, _impl_.data_len_), 1>(),
     {16, 1, 0, PROTOBUF_FIELD_OFFSET(req_head, _impl_.data_len_)}},
    // optional int32 protocol_code = 1;
    {::_pbi::TcParser::SingularVarintNoZag1<::uint32_t, offsetof(req_head, _impl_.protocol_code_), 0>(),
     {8, 0, 0, PROTOBUF_FIELD_OFFSET(req_head, _impl_.protocol_code_)}},
  }}, {{
    65535, 65535
  }}, {{
    // optional int32 protocol_code = 1;
    {PROTOBUF_FIELD_OFFSET(req_head, _impl_.protocol_code_), _Internal::kHasBitsOffset + 0, 0,
    (0 | ::_fl::kFcOptional | ::_fl::kInt32)},
    // optional int32 data_len = 2;
    {PROTOBUF_FIELD_OFFSET(req_head, _impl_.data_len_), _Internal::kHasBitsOffset + 1, 0,
    (0 | ::_fl::kFcOptional | ::_fl::kInt32)},
  }},
  // no aux_entries
  {{
  }},
};

::uint8_t* req_head::_InternalSerialize(
    ::uint8_t* target,
    ::google::protobuf::io::EpsCopyOutputStream* stream) const {
  // @@protoc_insertion_point(serialize_to_array_start:pb_common.req_head)
  ::uint32_t cached_has_bits = 0;
  (void)cached_has_bits;

  cached_has_bits = _impl_._has_bits_[0];
  // optional int32 protocol_code = 1;
  if (cached_has_bits & 0x00000001u) {
    target = ::google::protobuf::internal::WireFormatLite::
        WriteInt32ToArrayWithField<1>(
            stream, this->_internal_protocol_code(), target);
  }

  // optional int32 data_len = 2;
  if (cached_has_bits & 0x00000002u) {
    target = ::google::protobuf::internal::WireFormatLite::
        WriteInt32ToArrayWithField<2>(
            stream, this->_internal_data_len(), target);
  }

  if (PROTOBUF_PREDICT_FALSE(_internal_metadata_.have_unknown_fields())) {
    target =
        ::_pbi::WireFormat::InternalSerializeUnknownFieldsToArray(
            _internal_metadata_.unknown_fields<::google::protobuf::UnknownFieldSet>(::google::protobuf::UnknownFieldSet::default_instance), target, stream);
  }
  // @@protoc_insertion_point(serialize_to_array_end:pb_common.req_head)
  return target;
}

::size_t req_head::ByteSizeLong() const {
// @@protoc_insertion_point(message_byte_size_start:pb_common.req_head)
  ::size_t total_size = 0;

  ::uint32_t cached_has_bits = 0;
  // Prevent compiler warnings about cached_has_bits being unused
  (void) cached_has_bits;

  cached_has_bits = _impl_._has_bits_[0];
  if (cached_has_bits & 0x00000003u) {
    // optional int32 protocol_code = 1;
    if (cached_has_bits & 0x00000001u) {
      total_size += ::_pbi::WireFormatLite::Int32SizePlusOne(
          this->_internal_protocol_code());
    }

    // optional int32 data_len = 2;
    if (cached_has_bits & 0x00000002u) {
      total_size += ::_pbi::WireFormatLite::Int32SizePlusOne(
          this->_internal_data_len());
    }

  }
  return MaybeComputeUnknownFieldsSize(total_size, &_impl_._cached_size_);
}

const ::google::protobuf::Message::ClassData req_head::_class_data_ = {
    req_head::MergeImpl,
    nullptr,  // OnDemandRegisterArenaDtor
};
const ::google::protobuf::Message::ClassData* req_head::GetClassData() const {
  return &_class_data_;
}

void req_head::MergeImpl(::google::protobuf::Message& to_msg, const ::google::protobuf::Message& from_msg) {
  auto* const _this = static_cast<req_head*>(&to_msg);
  auto& from = static_cast<const req_head&>(from_msg);
  // @@protoc_insertion_point(class_specific_merge_from_start:pb_common.req_head)
  ABSL_DCHECK_NE(&from, _this);
  ::uint32_t cached_has_bits = 0;
  (void) cached_has_bits;

  cached_has_bits = from._impl_._has_bits_[0];
  if (cached_has_bits & 0x00000003u) {
    if (cached_has_bits & 0x00000001u) {
      _this->_impl_.protocol_code_ = from._impl_.protocol_code_;
    }
    if (cached_has_bits & 0x00000002u) {
      _this->_impl_.data_len_ = from._impl_.data_len_;
    }
    _this->_impl_._has_bits_[0] |= cached_has_bits;
  }
  _this->_internal_metadata_.MergeFrom<::google::protobuf::UnknownFieldSet>(from._internal_metadata_);
}

void req_head::CopyFrom(const req_head& from) {
// @@protoc_insertion_point(class_specific_copy_from_start:pb_common.req_head)
  if (&from == this) return;
  Clear();
  MergeFrom(from);
}

PROTOBUF_NOINLINE bool req_head::IsInitialized() const {
  return true;
}

::_pbi::CachedSize* req_head::AccessCachedSize() const {
  return &_impl_._cached_size_;
}
void req_head::InternalSwap(req_head* PROTOBUF_RESTRICT other) {
  using std::swap;
  _internal_metadata_.InternalSwap(&other->_internal_metadata_);
  swap(_impl_._has_bits_[0], other->_impl_._has_bits_[0]);
  ::google::protobuf::internal::memswap<
      PROTOBUF_FIELD_OFFSET(req_head, _impl_.data_len_)
      + sizeof(req_head::_impl_.data_len_)
      - PROTOBUF_FIELD_OFFSET(req_head, _impl_.protocol_code_)>(
          reinterpret_cast<char*>(&_impl_.protocol_code_),
          reinterpret_cast<char*>(&other->_impl_.protocol_code_));
}

::google::protobuf::Metadata req_head::GetMetadata() const {
  return ::_pbi::AssignDescriptors(
      &descriptor_table_pb_5fcommon_2eproto_getter, &descriptor_table_pb_5fcommon_2eproto_once,
      file_level_metadata_pb_5fcommon_2eproto[0]);
}
// ===================================================================

class req_test::_Internal {
 public:
  using HasBits = decltype(std::declval<req_test>()._impl_._has_bits_);
  static constexpr ::int32_t kHasBitsOffset =
    8 * PROTOBUF_FIELD_OFFSET(req_test, _impl_._has_bits_);
  static void set_has_n1(HasBits* has_bits) {
    (*has_bits)[0] |= 1u;
  }
};

req_test::req_test(::google::protobuf::Arena* arena)
    : ::google::protobuf::Message(arena) {
  SharedCtor(arena);
  // @@protoc_insertion_point(arena_constructor:pb_common.req_test)
}
req_test::req_test(
    ::google::protobuf::Arena* arena, const req_test& from)
    : req_test(arena) {
  MergeFrom(from);
}
inline PROTOBUF_NDEBUG_INLINE req_test::Impl_::Impl_(
    ::google::protobuf::internal::InternalVisibility visibility,
    ::google::protobuf::Arena* arena)
      : _cached_size_{0} {}

inline void req_test::SharedCtor(::_pb::Arena* arena) {
  new (&_impl_) Impl_(internal_visibility(), arena);
  _impl_.n1_ = {};
}
req_test::~req_test() {
  // @@protoc_insertion_point(destructor:pb_common.req_test)
  _internal_metadata_.Delete<::google::protobuf::UnknownFieldSet>();
  SharedDtor();
}
inline void req_test::SharedDtor() {
  ABSL_DCHECK(GetArena() == nullptr);
  _impl_.~Impl_();
}

PROTOBUF_NOINLINE void req_test::Clear() {
// @@protoc_insertion_point(message_clear_start:pb_common.req_test)
  PROTOBUF_TSAN_WRITE(&_impl_._tsan_detect_race);
  ::uint32_t cached_has_bits = 0;
  // Prevent compiler warnings about cached_has_bits being unused
  (void) cached_has_bits;

  _impl_.n1_ = 0;
  _impl_._has_bits_.Clear();
  _internal_metadata_.Clear<::google::protobuf::UnknownFieldSet>();
}

const char* req_test::_InternalParse(
    const char* ptr, ::_pbi::ParseContext* ctx) {
  ptr = ::_pbi::TcParser::ParseLoop(this, ptr, ctx, &_table_.header);
  return ptr;
}


PROTOBUF_CONSTINIT PROTOBUF_ATTRIBUTE_INIT_PRIORITY1
const ::_pbi::TcParseTable<0, 1, 0, 0, 2> req_test::_table_ = {
  {
    PROTOBUF_FIELD_OFFSET(req_test, _impl_._has_bits_),
    0, // no _extensions_
    1, 0,  // max_field_number, fast_idx_mask
    offsetof(decltype(_table_), field_lookup_table),
    4294967294,  // skipmap
    offsetof(decltype(_table_), field_entries),
    1,  // num_field_entries
    0,  // num_aux_entries
    offsetof(decltype(_table_), field_names),  // no aux_entries
    &_req_test_default_instance_._instance,
    ::_pbi::TcParser::GenericFallback,  // fallback
  }, {{
    // optional int32 n1 = 1;
    {::_pbi::TcParser::SingularVarintNoZag1<::uint32_t, offsetof(req_test, _impl_.n1_), 0>(),
     {8, 0, 0, PROTOBUF_FIELD_OFFSET(req_test, _impl_.n1_)}},
  }}, {{
    65535, 65535
  }}, {{
    // optional int32 n1 = 1;
    {PROTOBUF_FIELD_OFFSET(req_test, _impl_.n1_), _Internal::kHasBitsOffset + 0, 0,
    (0 | ::_fl::kFcOptional | ::_fl::kInt32)},
  }},
  // no aux_entries
  {{
  }},
};

::uint8_t* req_test::_InternalSerialize(
    ::uint8_t* target,
    ::google::protobuf::io::EpsCopyOutputStream* stream) const {
  // @@protoc_insertion_point(serialize_to_array_start:pb_common.req_test)
  ::uint32_t cached_has_bits = 0;
  (void)cached_has_bits;

  cached_has_bits = _impl_._has_bits_[0];
  // optional int32 n1 = 1;
  if (cached_has_bits & 0x00000001u) {
    target = ::google::protobuf::internal::WireFormatLite::
        WriteInt32ToArrayWithField<1>(
            stream, this->_internal_n1(), target);
  }

  if (PROTOBUF_PREDICT_FALSE(_internal_metadata_.have_unknown_fields())) {
    target =
        ::_pbi::WireFormat::InternalSerializeUnknownFieldsToArray(
            _internal_metadata_.unknown_fields<::google::protobuf::UnknownFieldSet>(::google::protobuf::UnknownFieldSet::default_instance), target, stream);
  }
  // @@protoc_insertion_point(serialize_to_array_end:pb_common.req_test)
  return target;
}

::size_t req_test::ByteSizeLong() const {
// @@protoc_insertion_point(message_byte_size_start:pb_common.req_test)
  ::size_t total_size = 0;

  ::uint32_t cached_has_bits = 0;
  // Prevent compiler warnings about cached_has_bits being unused
  (void) cached_has_bits;

  // optional int32 n1 = 1;
  cached_has_bits = _impl_._has_bits_[0];
  if (cached_has_bits & 0x00000001u) {
    total_size += ::_pbi::WireFormatLite::Int32SizePlusOne(
        this->_internal_n1());
  }

  return MaybeComputeUnknownFieldsSize(total_size, &_impl_._cached_size_);
}

const ::google::protobuf::Message::ClassData req_test::_class_data_ = {
    req_test::MergeImpl,
    nullptr,  // OnDemandRegisterArenaDtor
};
const ::google::protobuf::Message::ClassData* req_test::GetClassData() const {
  return &_class_data_;
}

void req_test::MergeImpl(::google::protobuf::Message& to_msg, const ::google::protobuf::Message& from_msg) {
  auto* const _this = static_cast<req_test*>(&to_msg);
  auto& from = static_cast<const req_test&>(from_msg);
  // @@protoc_insertion_point(class_specific_merge_from_start:pb_common.req_test)
  ABSL_DCHECK_NE(&from, _this);
  ::uint32_t cached_has_bits = 0;
  (void) cached_has_bits;

  if ((from._impl_._has_bits_[0] & 0x00000001u) != 0) {
    _this->_internal_set_n1(from._internal_n1());
  }
  _this->_internal_metadata_.MergeFrom<::google::protobuf::UnknownFieldSet>(from._internal_metadata_);
}

void req_test::CopyFrom(const req_test& from) {
// @@protoc_insertion_point(class_specific_copy_from_start:pb_common.req_test)
  if (&from == this) return;
  Clear();
  MergeFrom(from);
}

PROTOBUF_NOINLINE bool req_test::IsInitialized() const {
  return true;
}

::_pbi::CachedSize* req_test::AccessCachedSize() const {
  return &_impl_._cached_size_;
}
void req_test::InternalSwap(req_test* PROTOBUF_RESTRICT other) {
  using std::swap;
  _internal_metadata_.InternalSwap(&other->_internal_metadata_);
  swap(_impl_._has_bits_[0], other->_impl_._has_bits_[0]);
        swap(_impl_.n1_, other->_impl_.n1_);
}

::google::protobuf::Metadata req_test::GetMetadata() const {
  return ::_pbi::AssignDescriptors(
      &descriptor_table_pb_5fcommon_2eproto_getter, &descriptor_table_pb_5fcommon_2eproto_once,
      file_level_metadata_pb_5fcommon_2eproto[1]);
}
// @@protoc_insertion_point(namespace_scope)
}  // namespace pb_common
namespace google {
namespace protobuf {
}  // namespace protobuf
}  // namespace google
// @@protoc_insertion_point(global_scope)
#include "google/protobuf/port_undef.inc"
