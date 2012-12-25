require 'spec_helper'

describe CASinoCore::Processor::ProxyTicketProvider do
  describe '#process' do
    let(:listener) { Object.new }
    let(:processor) { described_class.new(listener) }
    let(:params) { { targetService: 'this_does_not_have_to_be_a_url' } }

    before(:each) do
      listener.stub(:request_failed)
      listener.stub(:request_succeeded)
    end

    context 'without proxy-granting ticket' do
      it 'calls the #request_failed method on the listener' do
        listener.should_receive(:request_failed)
        processor.process(params)
      end

      it 'does not create a proxy ticket' do
        lambda do
          processor.process(params)
        end.should_not change(CASinoCore::Model::ProxyTicket, :count)
      end
    end

    context 'with a not-existing proxy-granting ticket' do
      let(:params_with_deleted_pgt) { params.merge(pgt: 'PGT-123453789') }

      it 'calls the #request_failed method on the listener' do
        listener.should_receive(:request_failed)
        processor.process(params_with_deleted_pgt)
      end

      it 'does not create a proxy ticket' do
        lambda do
          processor.process(params_with_deleted_pgt)
        end.should_not change(CASinoCore::Model::ProxyTicket, :count)
      end
    end

    context 'with a proxy-granting ticket' do
      let(:ticket_granting_ticket) {
        CASinoCore::Model::TicketGrantingTicket.create!({
          ticket: 'TGC-Qu6B5IVQ7RmLc972TruM9u',
          username: 'test'
        })
      }
      let(:service_ticket) { ticket_granting_ticket.service_tickets.create! ticket: 'ST-2nOcXx56dtPTsB069yYf0h', service: 'http://www.example.com/' }
      let(:proxy_granting_ticket) {
        service_ticket.proxy_granting_tickets.create! ticket: 'PGT-OIE42ZadV3B9VcaG2xMjAf', iou: 'PGTIOU-PYg4CCPQHNyyS9s6bJF6Rg'
      }
      let(:params_with_valid_pgt) { params.merge(pgt: proxy_granting_ticket.ticket) }

      it 'calls the #request_succeeded method on the listener' do
        listener.should_receive(:request_succeeded)
        processor.process(params_with_valid_pgt)
      end

      it 'does not create a proxy ticket' do
        lambda do
          processor.process(params_with_valid_pgt)
        end.should change(proxy_granting_ticket.proxy_tickets, :count).by(1)
      end

      it 'includes the proxy ticket in the response' do
        listener.should_receive(:request_succeeded) do |response|
          proxy_ticket = CASinoCore::Model::ProxyTicket.last
          response.should =~ /<cas:proxyTicket>#{proxy_ticket.ticket}<\/cas:proxyTicket>/
        end
        processor.process(params_with_valid_pgt)
      end
    end
  end
end
