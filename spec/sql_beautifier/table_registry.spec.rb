# frozen_string_literal: true

RSpec.describe SqlBeautifier::TableRegistry do
  ############################################################################
  ## #alias_for
  ############################################################################

  describe "#alias_for" do
    let(:registry) { described_class.new(from_clause) }
    let(:output) { registry.alias_for(table_name) }

    context "with a single table" do
      let(:from_clause) { "users" }
      let(:table_name) { "users" }

      it "returns the initials-based alias" do
        expect(output).to eq("u")
      end
    end

    context "with an underscore-separated table" do
      let(:from_clause) { "active_storage_blobs" }
      let(:table_name) { "active_storage_blobs" }

      it "returns the initials from each segment" do
        expect(output).to eq("asb")
      end
    end

    context "with non-conflicting multi-word aliases" do
      let(:from_clause) { "users inner join user_sessions on user_sessions.user_id = users.id" }

      context "when looking up users" do
        let(:table_name) { "users" }

        it "returns distinct initials" do
          expect(output).to eq("u")
        end
      end

      context "when looking up user_sessions" do
        let(:table_name) { "user_sessions" }

        it "returns distinct initials" do
          expect(output).to eq("us")
        end
      end
    end

    context "with conflicting aliases" do
      let(:from_clause) { "updates inner join uploads on uploads.id = updates.upload_id" }

      context "when looking up updates" do
        let(:table_name) { "updates" }

        it "disambiguates with a counter" do
          expect(output).to eq("u1")
        end
      end

      context "when looking up uploads" do
        let(:table_name) { "uploads" }

        it "disambiguates with a counter" do
          expect(output).to eq("u2")
        end
      end
    end

    context "with three or more conflicting aliases" do
      let(:from_clause) { "updates inner join uploads on uploads.id = updates.upload_id inner join urls on urls.upload_id = uploads.id" }

      context "when looking up updates" do
        let(:table_name) { "updates" }

        it "disambiguates with an incrementing counter" do
          expect(output).to eq("u1")
        end
      end

      context "when looking up uploads" do
        let(:table_name) { "uploads" }

        it "disambiguates with an incrementing counter" do
          expect(output).to eq("u2")
        end
      end

      context "when looking up urls" do
        let(:table_name) { "urls" }

        it "disambiguates with an incrementing counter" do
          expect(output).to eq("u3")
        end
      end
    end

    context "with a table not in the registry" do
      let(:from_clause) { "users" }
      let(:table_name) { "orders" }

      it "returns nil" do
        expect(output).to be_nil
      end
    end

    context "with an explicit alias" do
      let(:from_clause) { "users usr" }
      let(:table_name) { "users" }

      it "returns the explicit alias" do
        expect(output).to eq("usr")
      end
    end

    context "with an explicit AS alias" do
      let(:from_clause) { "users as usr" }
      let(:table_name) { "users" }

      it "returns the explicit alias" do
        expect(output).to eq("usr")
      end
    end
  end

  ############################################################################
  ## #table_map
  ############################################################################

  describe "#table_map" do
    let(:registry) { described_class.new(from_clause) }
    let(:output) { registry.table_map }

    context "with a single table" do
      let(:from_clause) { "users" }

      it "contains the table" do
        expect(output.keys).to contain_exactly("users")
      end

      it "maps to the initials-based alias" do
        expect(output["users"]).to eq("u")
      end
    end

    context "with multiple join types" do
      let(:from_clause) { "users left join profiles on profiles.user_id = users.id inner join orders on orders.user_id = users.id" }

      it "contains all tables from the FROM clause" do
        expect(output.keys).to contain_exactly("users", "profiles", "orders")
      end

      it "maps each table to its alias" do
        expect(output["users"]).to eq("u")
        expect(output["profiles"]).to eq("p")
        expect(output["orders"]).to eq("o")
      end
    end

    context "with explicit and generated aliases that share initials" do
      let(:from_clause) { "users u inner join uploads on uploads.user_id = users.id" }

      it "keeps the explicit alias for users" do
        expect(output["users"]).to eq("u")
      end

      it "avoids generated alias collisions" do
        expect(output["uploads"]).to eq("u1")
      end
    end
  end

  ############################################################################
  ## #apply_aliases
  ############################################################################

  describe "#apply_aliases" do
    let(:registry) { described_class.new(from_clause) }
    let(:output) { registry.apply_aliases(value) }
    let(:from_clause) { "users inner join orders on orders.user_id = users.id" }

    context "with table references" do
      let(:value) { "users.id = orders.user_id" }

      it "replaces table_name. with alias." do
        expect(output).to eq("u.id = o.user_id")
      end
    end

    context "without table references" do
      let(:value) { "active = true" }

      it "does not modify the text" do
        expect(output).to eq("active = true")
      end
    end

    context "with multiple references to the same table" do
      let(:value) { "users.first_name, users.last_name, orders.total" }

      it "replaces all occurrences" do
        expect(output).to eq("u.first_name, u.last_name, o.total")
      end
    end

    context "when a longer table name shares a prefix with a shorter one" do
      let(:from_clause) { "users inner join user_sessions on user_sessions.user_id = users.id" }
      let(:value) { "user_sessions.user_id = users.id" }

      it "replaces the longer name correctly without partial matches" do
        expect(output).to eq("us.user_id = u.id")
      end
    end

    context "with a table reference inside a string literal" do
      let(:value) { "users.id = 1 and message = 'users.id'" }

      it "does not replace inside the string literal" do
        expect(output).to eq("u.id = 1 and message = 'users.id'")
      end
    end

    context "with escaped single quotes in a string literal" do
      let(:value) { "users.id = 1 and name = 'users.o''brien'" }

      it "preserves the escaped quote and does not replace inside the literal" do
        expect(output).to eq("u.id = 1 and name = 'users.o''brien'")
      end
    end

    context "with a table reference inside a quoted identifier" do
      let(:value) { 'users.id = 1 and "users.name" = 2' }

      it "does not replace inside the quoted identifier" do
        expect(output).to eq('u.id = 1 and "users.name" = 2')
      end
    end

    context "when a registered table name is a suffix of an unregistered identifier" do
      let(:value) { "archived_users.id = users.id" }

      it "does not replace the suffix match" do
        expect(output).to eq("archived_users.id = u.id")
      end
    end

    context "with disambiguated counter aliases" do
      let(:from_clause) { "updates inner join uploads on uploads.update_id = updates.id" }
      let(:value) { "updates.id = uploads.update_id" }

      it "replaces with counter-based aliases" do
        expect(output).to eq("u1.id = u2.update_id")
      end
    end

    context "with an explicit alias in the FROM clause" do
      let(:from_clause) { "users usr inner join orders o on o.user_id = usr.id" }
      let(:value) { "users.id = orders.user_id and usr.active = true" }

      it "replaces table references with explicit aliases" do
        expect(output).to eq("usr.id = o.user_id and usr.active = true")
      end
    end
  end
end
