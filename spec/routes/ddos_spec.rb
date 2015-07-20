require 'spec_helper'

RSpec.describe Healer do
  let(:api_namespace) { '/healer/v1' }
  let(:fixtures) { File.join('spec', 'fixtures', 'fast_net_mon') }

  describe 'POST /ddos/notify' do
    context 'body is a valid FastNetMon report' do
      let(:fastnetmon_report_ip_192_168_0_1) do
        File.read( File.join(fixtures, 'report_ip-192_168_0_1.txt') )
      end

      it 'returns http status ok' do
        post "#{api_namespace}/ddos/notify", fastnetmon_report_ip_192_168_0_1
        expect(last_response.status).to eq 200
      end
    end
  end
end
