# frozen_string_literal: true

describe MysqlFramework::SqlQuery do
  let(:gems) { MysqlFramework::SqlTable.new('gems') }
  let(:versions) { MysqlFramework::SqlTable.new('versions') }

  describe 'building a query' do
    it 'builds the insert query as expected' do
      subject.insert(gems, 15)
        .into(
          gems[:name],
          gems[:author],
          gems[:created_at],
          gems[:updated_at]
        )
        .values(
          'mysql_framework',
          'sage',
          '2018-06-28 10:00:00',
          '2018-06-28 10:00:00'
        )

      expect(subject.sql).to eq('INSERT INTO `gems` PARTITION (p15) (`gems`.`name`, `gems`.`author`, `gems`.`created_at`, `gems`.`updated_at`) VALUES (?, ?, ?, ?)')
      expect(subject.params).to eq(['mysql_framework', 'sage', '2018-06-28 10:00:00', '2018-06-28 10:00:00'])
    end

    it 'builds the update query as expected' do
      subject.update(gems, 20)
        .set(
          name: 'mysql_framework',
          updated_at: '2018-06-28 13:00:00'
        )
        .where(gems[:id].eq('12345'))

      expect(subject.sql).to eq('UPDATE `gems` PARTITION (p20) SET `name` = ?, `updated_at` = ? WHERE (`gems`.`id` = ?)')
      expect(subject.params).to eq(['mysql_framework', '2018-06-28 13:00:00', '12345'])
    end

    it 'builds the delete query as expected' do
      subject.delete.from(gems, 30).where(gems[:id].eq('45678'))

      expect(subject.sql).to eq('DELETE FROM `gems` PARTITION (p30) WHERE (`gems`.`id` = ?)')
      expect(subject.params).to eq(['45678'])
    end

    it 'builds a basic select query as expected' do
      subject.select('*').from(gems, 40).where(gems[:id].eq('9876'))

      expect(subject.sql).to eq('SELECT * FROM `gems` PARTITION (p40) WHERE (`gems`.`id` = ?)')
      expect(subject.params).to eq(['9876'])
    end

    it 'builds a joined select query as expected' do
      subject.select('*')
        .from(gems, 40)
        .join(versions).on(versions[:gem_id], gems[:id])
        .where(gems[:id].eq('9876'))

      expect(subject.sql).to eq('SELECT * FROM `gems` PARTITION (p40) JOIN `versions` ON `versions`.`gem_id` = `gems`.`id` WHERE (`gems`.`id` = ?)')
      expect(subject.params).to eq(['9876'])
    end
  end

  describe '#select' do
    it 'sets the sql for a select statement' do
      subject.select(gems[:id], gems[:name])

      expect(subject.sql).to eq('SELECT `gems`.`id`, `gems`.`name`')
    end
  end

  describe '#delete' do
    it 'sets the sql for a delete statement' do
      subject.delete

      expect(subject.sql).to eq('DELETE')
    end
  end

  describe '#update' do
    it 'sets the sql for an update statement' do
      subject.update(gems)

      expect(subject.sql).to eq('UPDATE `gems`')
    end

    context 'when a partition is specified' do
      it 'sets the sql for an update statement' do
        subject.update(gems, 25)

        expect(subject.sql).to eq('UPDATE `gems` PARTITION (p25)')
      end
    end
  end

  describe '#insert' do
    it 'sets the sql for an insert statement' do
      subject.insert(gems)

      expect(subject.sql).to eq('INSERT INTO `gems`')
    end

    context 'when a partition is specified' do
      it 'sets the sql for an insert statement' do
        subject.insert(gems, 35)

        expect(subject.sql).to eq('INSERT INTO `gems` PARTITION (p35)')
      end
    end
  end

  describe '#into' do
    it 'sets the sql for an into statement' do
      subject.into(gems[:name], gems[:author], gems[:created_at])

      expect(subject.sql).to eq('(`gems`.`name`, `gems`.`author`, `gems`.`created_at`)')
    end
  end

  describe '#values' do
    it 'sets the sql for the values statement' do
      subject.values('mysql_framework', 'sage', '2016-06-28 10:00:00')

      expect(subject.sql).to eq('VALUES (?, ?, ?)')
    end
  end

  describe '#bulk_values' do
    it 'sets the sql for the values statement' do
      bulk_values = [
        ['mysql_framework', 'sage', '2016-06-28 10:00:00'],
        ['mysql_framework', 'sage', '2016-06-28 10:00:00']
      ]

      subject.bulk_values(bulk_values)

      expect(subject.sql).to eq('VALUES(?, ?, ?),(?, ?, ?)')
      expect(subject.params).to eq(bulk_values.flatten)
    end
  end

  describe '#set' do
    it 'sets the sql for the set statement' do
      subject.set(name: 'mysql_framework', author: 'sage', created_at: '2016-06-28 10:00:00')

      expect(subject.sql).to eq('SET `name` = ?, `author` = ?, `created_at` = ?')
    end
  end

  describe '#increment' do
    it 'appends the sql for the increment statement' do
      subject.set(updated_at: '2016-01-15 19:00:00').increment(count: 1)

      expect(subject.sql).to eq('SET `updated_at` = ?, `count` = `count` + 1')
    end

    context 'when a set statement has not been issued' do
      it 'appends the sql for the increment statement' do
        subject.increment(count: 1)

        expect(subject.sql).to eq('SET `count` = `count` + 1')
      end
    end
  end

  describe '#decrement' do
    it 'appends the sql for the decrement statement' do
      subject.set(updated_at: '2016-01-15 19:00:00').decrement(count: 1)

      expect(subject.sql).to eq('SET `updated_at` = ?, `count` = `count` - 1')
    end

    context 'when a set statement has not been issued' do
      it 'appends the sql for the decrement statement' do
        subject.decrement(count: 1)

        expect(subject.sql).to eq('SET `count` = `count` - 1')
      end
    end
  end

  describe '#from' do
    it 'sets the sql for a from statement' do
      subject.from(gems)

      expect(subject.sql).to eq('FROM `gems`')
    end

    context 'when a partition is specified' do
      it 'sets the sql for a from statement' do
        subject.from(gems, 45)

        expect(subject.sql).to eq('FROM `gems` PARTITION (p45)')
      end
    end
  end

  describe '#where' do
    before(:each) { subject.where(gems[:author].eq('sage'), gems[:created_at].gt('2018-01-01 00:00:00')) }

    it 'appends where to the sql' do
      expect(subject.sql).to include('WHERE')
    end

    it 'sets the sql for the where statement' do
      expect(subject.sql).to eq('WHERE (`gems`.`author` = ? AND `gems`.`created_at` > ?)')
    end

    context 'when the sql already contains a where' do
      it 'does not append an extra where' do
        subject.and.where(gems[:name].eq('mysql_framework'))

        expect(subject.sql).to eq('WHERE (`gems`.`author` = ? AND `gems`.`created_at` > ?) AND (`gems`.`name` = ?)')
      end
    end

    context 'when the condition includes an array of parameters' do
      it 'concats the parameter collections' do
        subject.and.where(gems[:name].in('a','b'))
        expect(subject.sql).to eq('WHERE (`gems`.`author` = ? AND `gems`.`created_at` > ?) AND (`gems`.`name` IN (?, ?))')
      end
    end
  end

  describe '#and' do
    it 'appends the sql for an and statement' do
      subject.and

      expect(subject.sql).to eq('AND')
    end
  end

  describe '#or' do
    it 'appends the sql for an or statement' do
      subject.or

      expect(subject.sql).to eq('OR')
    end
  end

  describe '#order' do
    it 'appends the sql for an order statement' do
      subject.order(gems[:created_at], gems[:updated_at])

      expect(subject.sql).to eq('ORDER BY `gems`.`created_at`, `gems`.`updated_at`')
    end
  end

  describe '#order_desc' do
    it 'appends the sql for an order descending statement' do
      subject.order_desc(gems[:created_at], gems[:updated_at])

      expect(subject.sql).to eq('ORDER BY `gems`.`created_at`, `gems`.`updated_at` DESC')
    end
  end

  describe '#limit' do
    it 'appends the sql for a limit statement' do
      subject.limit(10)

      expect(subject.sql).to eq('LIMIT 10')
    end
  end

  describe '#offset' do
    it 'appends the sql for an offset statement' do
      subject.limit(10).offset(5)

      expect(subject.sql).to eq('LIMIT 10 OFFSET 5')
    end

    context 'when a limit statement is not found' do
      it 'raises an error' do
        expect { subject.offset(5) }.to raise_error(RuntimeError)
      end
    end
  end

  describe '#join' do
    it 'appends the sql for a join statement' do
      subject.join(versions)

      expect(subject.sql).to eq('JOIN `versions`')
    end

    context 'when a type is supplied' do
      it 'appends the sql for a join statement' do
        subject.join(versions, type: 'LEFT OUTER')

        expect(subject.sql).to eq('LEFT OUTER JOIN `versions`')
      end
    end
  end

  describe '#on' do
    it 'appends the sql for the on statement' do
      subject.on(gems[:id], versions[:gem_id])

      expect(subject.sql).to eq('ON `gems`.`id` = `versions`.`gem_id`')
    end
  end

  describe '#group_by' do
    it 'appends the sql for a group by statement' do
      subject.group_by(gems[:created_at], gems[:updated_at])

      expect(subject.sql).to eq('GROUP BY `gems`.`created_at`, `gems`.`updated_at`')
    end
  end

  describe '#having' do
    before(:each) { subject.having(gems[:count].gt(1), gems[:count].lt(10)) }

    it 'appends having to the sql' do
      expect(subject.sql).to include('HAVING')
    end

    it 'sets the sql for the having statement' do
      expect(subject.sql).to eq('HAVING (`gems`.`count` > ? AND `gems`.`count` < ?)')
    end

    context 'when the sql already contains a having' do
      it 'does not append an extra having' do
        subject.or.having(gems[:count].gt(20))

        expect(subject.sql).to eq('HAVING (`gems`.`count` > ? AND `gems`.`count` < ?) OR (`gems`.`count` > ?)')
      end
    end
  end

  describe '#lock' do
    it 'appends `FOR_UPDATE` to the query' do
      subject.select('*').from(gems).lock
      expect(subject.sql).to end_with('FOR UPDATE')
    end
  end

  describe '#on_duplicate' do
    let(:query) do
      subject.insert(gems)
        .into(
          gems[:id],
          gems[:name],
          gems[:author]
        )
        .values(
          1,
          'mysql_framework',
          'Bob Hope'
        )
    end

    context 'when no custom values are specified' do
      it 'updates with the value from the INSERT clause' do
        query.on_duplicate(
          {
            gems[:name] => nil,
            gems[:author] => nil
          }
        )

        expect(query.sql)
          .to end_with 'ON DUPLICATE KEY UPDATE `gems`.`name` = VALUES (`gems`.`name`), `gems`.`author` = VALUES (`gems`.`author`)'
      end
    end

    context 'when a custom value is specified' do
      it 'updates the value based on the custom value' do
        query.on_duplicate(
          {
            gems[:name] => '"mysql_alternative"',
            gems[:author] => '"Michael Caine"'
          }
        )

        expect(query.sql)
          .to end_with 'ON DUPLICATE KEY UPDATE `gems`.`name` = "mysql_alternative", `gems`.`author` = "Michael Caine"'
      end
    end

    context 'when column names are specified instead of SqlColumn objects' do
      it 'updates the value based on the custom column key names' do
        query.on_duplicate(
          {
            name: '"mysql_alternative"',
            author: '"Michael Caine"'
          }
        )

        expect(query.sql)
          .to end_with 'ON DUPLICATE KEY UPDATE name = "mysql_alternative", author = "Michael Caine"'
      end
    end
  end

  describe '#open_brackets' do
    it 'appends the sql for an (' do
      subject.open_brackets

      expect(subject.sql).to eq('(')
    end
  end

  describe '#close_brackets' do
    it 'appends the sql for an )' do
      subject.close_brackets

      expect(subject.sql).to eq(')')
    end
  end
end
