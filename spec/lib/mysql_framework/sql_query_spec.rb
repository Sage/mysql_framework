# frozen_string_literal: true

require 'spec_helper'

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

      expect(subject.sql).to eq('insert into `gems` partition(p15) (`gems`.`name`,`gems`.`author`,`gems`.`created_at`,`gems`.`updated_at`) values (?,?,?,?)')
      expect(subject.params).to eq(['mysql_framework', 'sage', '2018-06-28 10:00:00', '2018-06-28 10:00:00'])
    end

    it 'builds the update query as expected' do
      subject.update(gems, 20)
        .set(
          name: 'mysql_framework',
          updated_at: '2018-06-28 13:00:00'
        )
        .where(
          gems[:id].eq('12345')
        )

      expect(subject.sql).to eq('update `gems` partition(p20) set `name` = ?, `updated_at` = ? where (`gems`.`id` = ?)')
      expect(subject.params).to eq(['mysql_framework', '2018-06-28 13:00:00', '12345'])
    end

    it 'builds the delete query as expected' do
      subject.delete.from(gems, 30)
        .where(
          gems[:id].eq('45678')
        )

      expect(subject.sql).to eq('delete from `gems` partition(p30) where (`gems`.`id` = ?)')
      expect(subject.params).to eq(['45678'])
    end

    it 'builds a basic select query as expected' do
      subject.select('*')
        .from(gems, 40)
        .where(
          gems[:id].eq('9876')
        )

      expect(subject.sql).to eq('select * from `gems` partition(p40) where (`gems`.`id` = ?)')
      expect(subject.params).to eq(['9876'])
    end

    it 'builds a joined select query as expected' do
      subject.select('*')
        .from(gems, 40)
        .join(versions).on(versions[:gem_id], gems[:id])
        .where(
          gems[:id].eq('9876')
        )

      expect(subject.sql).to eq('select * from `gems` partition(p40) join `versions` on `versions`.`gem_id` = `gems`.`id` where (`gems`.`id` = ?)')
      expect(subject.params).to eq(['9876'])
    end
  end

  describe '#select' do
    it 'sets the sql for a select statement' do
      subject.select(gems[:id], gems[:name])
      expect(subject.sql).to eq('select `gems`.`id`,`gems`.`name`')
    end
  end

  describe '#delete' do
    it 'sets the sql for a delete statement' do
      subject.delete
      expect(subject.sql).to eq('delete')
    end
  end

  describe '#update' do
    it 'sets the sql for an update statement' do
      subject.update(gems)
      expect(subject.sql).to eq('update `gems`')
    end

    context 'when a partition is specified' do
      it 'sets the sql for an update statement' do
        subject.update(gems, 25)
        expect(subject.sql).to eq('update `gems` partition(p25)')
      end
    end
  end

  describe '#insert' do
    it 'sets the sql for an insert statement' do
      subject.insert(gems)
      expect(subject.sql).to eq('insert into `gems`')
    end

    context 'when a partition is specified' do
      it 'sets the sql for an insert statement' do
        subject.insert(gems, 35)
        expect(subject.sql).to eq('insert into `gems` partition(p35)')
      end
    end
  end

  describe '#into' do
    it 'sets the sql for an into statement' do
      subject.into(gems[:name], gems[:author], gems[:created_at])
      expect(subject.sql).to eq('(`gems`.`name`,`gems`.`author`,`gems`.`created_at`)')
    end
  end

  describe '#values' do
    it 'sets the sql for the values statement' do
      subject.values('mysql_framework', 'sage', '2016-06-28 10:00:00')
      expect(subject.sql).to eq('values (?,?,?)')
    end
  end

  describe '#set' do
    it 'sets the sql for the set statement' do
      subject.set(name: 'mysql_framework', author: 'sage', created_at: '2016-06-28 10:00:00')
      expect(subject.sql).to eq('set `name` = ?, `author` = ?, `created_at` = ?')
    end
  end

  describe '#from' do
    it 'sets the sql for a from statement' do
      subject.from(gems)
      expect(subject.sql).to eq('from `gems`')
    end

    context 'when a partition is specified' do
      it 'sets the sql for a from statement' do
        subject.from(gems, 45)
        expect(subject.sql).to eq('from `gems` partition(p45)')
      end
    end
  end

  describe '#where' do
    before :each do
      subject.where(gems['author'].eq('sage'), gems['created_at'].gt('2018-01-01 00:00:00'))
    end

    it 'appends where to the sql' do
      expect(subject.sql).to include('where')
    end

    it 'sets the sql for the where statement' do
      expect(subject.sql).to eq('where (`gems`.`author` = ? and `gems`.`created_at` > ?)')
    end

    context 'when the sql already contains a where' do
      it 'does not append an extra where' do
        subject.and.where(gems['name'].eq('mysql_framework'))
        expect(subject.sql).to eq('where (`gems`.`author` = ? and `gems`.`created_at` > ?) and (`gems`.`name` = ?)')
      end
    end
  end

  describe '#and' do
    it 'appends the sql for an and statement' do
      subject.and
      expect(subject.sql).to eq('and')
    end
  end

  describe '#or' do
    it 'appends the sql for an or statement' do
      subject.or
      expect(subject.sql).to eq('or')
    end
  end

  describe '#order' do
    it 'appends the sql for an order statement' do
      subject.order(gems[:created_at], gems[:updated_at])
      expect(subject.sql).to eq('order by `gems`.`created_at`,`gems`.`updated_at`')
    end
  end

  describe '#order_desc' do
    it 'appends the sql for an order descending statement' do
      subject.order_desc(gems[:created_at], gems[:updated_at])
      expect(subject.sql).to eq('order by `gems`.`created_at`,`gems`.`updated_at` desc')
    end
  end

  describe '#limit' do
    it 'appends the sql for a limit statement' do
      subject.limit(10)
      expect(subject.sql).to eq('limit 10')
    end
  end

  describe '#join' do
    it 'appends the sql for a join statement' do
      subject.join(versions)
      expect(subject.sql).to eq('join `versions`')
    end
  end

  describe '#on' do
    it 'appends the sql for the on statement' do
      subject.on(gems[:id], versions[:gem_id])
      expect(subject.sql).to eq('on `gems`.`id` = `versions`.`gem_id`')
    end
  end
end
