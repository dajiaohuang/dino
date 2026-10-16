namespace Xmpp.Test {

class CallInvitesTest : Gee.TestCase {
    public CallInvitesTest() {
        base("CallInvites");
        add_test("invite_uses_message_id", test_invite_uses_message_id);
        add_test("invite_uses_origin_id", test_invite_uses_origin_id);
        add_test("groupchat_invite_uses_room_stanza_id", test_groupchat_invite_uses_room_stanza_id);
        add_test("invite_child_id_is_legacy_fallback", test_invite_child_id_is_legacy_fallback);
        add_async_test("outgoing_invite_uses_call_id", test_outgoing_invite_uses_call_id);
    }

    private void test_invite_uses_message_id() {
        fail_if_not_eq_str(received_call_id(message_node("chat", "message-id", null, null)), "message-id");
    }

    private void test_invite_uses_origin_id() {
        fail_if_not_eq_str(received_call_id(message_node("chat", "message-id", "origin-id", null)), "origin-id");
    }

    private void test_groupchat_invite_uses_room_stanza_id() {
        fail_if_not_eq_str(received_call_id(message_node("groupchat", "message-id", null, "room-id")), "room-id");
    }

    private void test_invite_child_id_is_legacy_fallback() {
        fail_if_not_eq_str(received_call_id(message_node("chat", null, null, null, "legacy-id")), "legacy-id");
    }

    private void test_outgoing_invite_uses_call_id(Gee.TestFinishedCallback cb) {
        try {
            var stream = new CallInvitesTestStream(Jid.from_string("example.test"));
            stream.add_module(new MessageModule());
            stream.written.connect((node) => {
                fail_if_not_eq_str(node.get_attribute("id"), "call-id");
                cb();
            });
            new Xep.CallInvites.Module().send_muji_propose(stream, "call-id",
                    Jid.from_string("remote@example.test"),
                    Jid.from_string("room@conference.example.test"), false, MessageStanza.TYPE_CHAT);
        } catch (InvalidJidError e) {
            assert_not_reached();
        }
    }

    private string? received_call_id(StanzaNode node) {
        try {
            Jid local_jid = Jid.from_string("local@example.test/resource");
            var stream = new CallInvitesTestStream(Jid.from_string("example.test"));
            var message_module = new MessageModule();
            stream.add_module(message_module);

            var call_invites = new Xep.CallInvites.Module();
            call_invites.attach(stream);

            string? call_id = null;
            call_invites.call_proposed.connect((from, to, id, video, methods, message) => { call_id = id; });
            message_module.received_message(stream, new MessageStanza.from_stanza(node, local_jid));
            return call_id;
        } catch (InvalidJidError e) {
            assert_not_reached();
        }
        return null;
    }

    private StanzaNode message_node(string type, string? id, string? origin_id, string? stanza_id, string? legacy_id = null) {
        StanzaNode message = new StanzaNode.build("message")
                .put_attribute("from", type == MessageStanza.TYPE_GROUPCHAT ? "room@conference.example.test/nick" : "remote@example.test")
                .put_attribute("to", "local@example.test/resource")
                .put_attribute("type", type);
        if (id != null) message.put_attribute("id", id);
        if (origin_id != null) {
            message.put_node(new StanzaNode.build("origin-id", Xep.UniqueStableStanzaIDs.NS_URI)
                    .add_self_xmlns()
                    .put_attribute("id", origin_id));
        }
        if (stanza_id != null) {
            message.put_node(new StanzaNode.build("stanza-id", Xep.UniqueStableStanzaIDs.NS_URI)
                    .add_self_xmlns()
                    .put_attribute("by", "room@conference.example.test")
                    .put_attribute("id", stanza_id));
        }
        StanzaNode invite = new StanzaNode.build("invite", Xep.CallInvites.NS_URI).add_self_xmlns();
        if (legacy_id != null) invite.put_attribute("id", legacy_id);
        message.put_node(invite.put_node(new StanzaNode.build("muji", Xep.Muji.NS_URI)
                        .add_self_xmlns()
                        .put_attribute("room", "room@conference.example.test")));
        return message;
    }
}

class CallInvitesTestStream : XmppStream {
    public signal void written(StanzaNode node);

    public CallInvitesTestStream(Jid remote_name) {
        base(remote_name);
    }

    public override async void connect() throws IOError {}
    public override async void disconnect() throws IOError {}
    public override async StanzaNode read() throws IOError { throw new IOError.CLOSED("test stream has no input"); }
    public override void write(StanzaNode node, int io_priority = Priority.DEFAULT) {}
    public override async void write_async(StanzaNode node, int io_priority = Priority.DEFAULT, Cancellable? cancellable = null) throws IOError { written(node); }
    public override async void setup() throws IOError {}
}

}
