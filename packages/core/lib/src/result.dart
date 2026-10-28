/// Kết quả của một thao tác có thể lỗi,
/// thay cho ném exception qua ranh giới lớp.
sealed class Result<T> {
  const new();

  /// Áp [onOk] hoặc [onErr] tùy nhánh.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };
}

/// Nhánh thành công.
final class Ok<T> extends Result<T> {
  /// Tạo nhánh thành công.
  const new(this.value);

  /// Giá trị trả về.
  final T value;
}

/// Nhánh lỗi.
final class Err<T> extends Result<T> {
  /// Tạo nhánh lỗi.
  const new(this.failure);

  /// Mô tả lỗi.
  final Failure failure;
}

/// Lỗi có mã ổn định (để i18n và báo cáo), không mang dữ liệu nhạy cảm.
class Failure {
  /// Tạo lỗi với [code] và [message] dành cho log nội bộ.
  const new(this.code, [this.message = '']);

  /// Mã lỗi ổn định, ví dụ `sensor.unavailable`.
  final String code;

  /// Mô tả cho log nội bộ (không hiển thị cho người dùng).
  final String message;

  @override
  String toString() => 'Failure($code)';
}
