class ReportsAnalyst
  REPORT_TYPES = ["FastNetMon"]

  @queue = :report_to_analyze

  def process_report(report_type, report_payload)
   report = parser_by_type(report_type).new(report_payload).to_json
   RedisStorage.add report_as_json
  end

  def know?(type)
    ReportParser::KNOWN.include?(type)
  end

  def self.perform(report_type, report_payload)
    analyst = new
    analyst.process_report(report_type, report_payload)
    analyst.check_thresholds
  rescue Resque::TermException
    Resque.enqueue(self, report_type, report_payload)
  end

  private

  def parser_by_type(type)
    Object.const_get("ReportParser::#{type}")
  end
end
