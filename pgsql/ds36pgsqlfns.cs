/*
 * DVD Store 3/5 PostgresQL Functions - ds35pgsqlfns.cs
 *
 * Copyright (C) 2011 VMware, Inc. <jshah@vmware.com> and <tmuirhead@vmware.com>
 *
 * Provides interface functions for DVD Store driver program ds35xdriver.cs
 * See ds35xdriver.cs for compilation and syntax
 *
 *  11/11/2021 - Initial release of PostgreSQL version of DVD Store 3.5 Driver
 *			This version was based on the ds2sqlserverfns.cs DVD Store
 *			driver program for SQL Server.  Modifications were made to 
 *			adapt it for PostgreSQL.
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA  */



using System.Data;
using System.Diagnostics;
using Npgsql;
using NpgsqlTypes;


namespace ds2xdriver
{
  public class MembershipAnalyticsRow
  {
    public int? MembershipType { get; set; }
    public long ActiveMemberCount { get; set; }
    public long ExpiredMemberCount { get; set; }
    public long TotalOrders { get; set; }
    public decimal TotalRevenue { get; set; }
  }

  public class NewCustomerAnalyticsRow
  {
    public long Created { get; set; }
    public long TwoPlus { get; set; }
    public long ThreePlus { get; set; }
    public long TotalOrders { get; set; }
  }

  public class ReviewAnalyticsRow
  {
    public int Stars { get; set; }
    public long Reviews { get; set; }
    public long Added { get; set; }
    public decimal AvgHelp { get; set; }
    public long HighHelp { get; set; }
    public long LowHelp { get; set; }
  }

  public class PricePointAnalyticsRow
  {
    public string PriceEnding { get; set; }
    public long ProductCount { get; set; }
  }

  public class PricePointAnalyticsData
  {
    public List<PricePointAnalyticsRow> PricePoints { get; set; }
    public long NewProductsPurchased { get; set; }
  }

  public class InventoryAnalyticsRow
  {
    public long LowStockCount { get; set; }
    public long HighStockCount { get; set; }
    public long ReorderCount { get; set; }
    public decimal AvgInventory { get; set; }
    public long DeadStock { get; set; }
    public long LowSales { get; set; }
    public long MedSales { get; set; }
    public long HighSales { get; set; }
    public long TotalProducts { get; set; }
  }

  /// <summary>
  /// ds2pgsqlfns.cs: DVD Store 3 postgreSQL Functions
  /// </summary>
  public class ds2Interface
  {
    int ds2Interfaceid;
    string target_server;       //Added by GSK
    //string conn_str = "";
    int target_store_number = 1; // Added to support multiple stores - default is 1
    NpgsqlConnection objConn;
    NpgsqlCommand Login, New_Customer, Browse_By_Category, Browse_By_Actor, Browse_By_Title, Browse_By_Membership, Purchase;
    NpgsqlCommand New_Member, Get_Membership_Status, Renew_Membership, New_Prod_Review, New_Review_Helpfulness, New_Product;
    NpgsqlCommand Get_Prod_Reviews, Get_Prod_Reviews_By_Date, Get_Prod_Reviews_By_Stars, Get_Prod_Reviews_By_Actor, Get_Prod_Reviews_By_Title;
    NpgsqlCommand Remove_Review_By_Product, Remove_Unhelpful_Reviews, Remove_Reviews_By_Date, Adjust_Prices, Bulk_Price_Adjustment, Mark_Specials, Expire_Memberships, Purge_Old_Orders, Upgrade_Membership, Promotional_Membership, Get_Membership_Analytics, Get_New_Customer_Analytics, Get_Review_Analytics, Get_Price_Point_Analytics, Get_Inventory_Analytics;
    NpgsqlCommand[] CostQuery = new NpgsqlCommand[101];

    //
    //-------------------------------------------------------------------------------------------------
    // 

    // (Overloaded constructor to support multiple stores within single DS3 instance)
    public ds2Interface(int ds2interfaceid, string target_name, int target_store)
    {
      ds2Interfaceid = ds2interfaceid;
      target_server = target_name;
      target_store_number = target_store;
      string sConnectionString = "Server=" + target_server + ";Port=5432;User ID=ds3;Password=ds3;Database=ds3;MinPoolSize=8;MaxPoolSize=200;Timeout=1024;CommandTimeout=1200;ConnectionIdleLifetime=18000";
      objConn = new NpgsqlConnection(sConnectionString);

      //conn_str = "Server=" + target_server + ";User ID=ds3;Password=ds3;Database=ds3";
      //Console.WriteLine("ds2Interface {0} created", ds2Interfaceid);

      // Set up SQL stored procedure calls and associated parameters
      Login = new NpgsqlCommand("LOGIN" + target_store_number, objConn);
      Login.CommandType = CommandType.StoredProcedure;
      Login.Parameters.Add("username_in", NpgsqlDbType.Varchar, 50);
      Login.Parameters.Add("password_in", NpgsqlDbType.Varchar, 50);

      New_Customer = new NpgsqlCommand("NEW_CUSTOMER" + target_store_number, objConn);
      New_Customer.CommandType = CommandType.StoredProcedure;
      New_Customer.Parameters.Add("firstname_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("lastname_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("address1_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("address2_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("city_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("state_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("zip_in", NpgsqlDbType.Varchar, 9);
      New_Customer.Parameters.Add("country_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("region_in", NpgsqlDbType.Smallint);
      New_Customer.Parameters.Add("email_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("phone_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("creditcardtype_in", NpgsqlDbType.Integer);
      New_Customer.Parameters.Add("creditcard_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("creditcardexpiration_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("password_in", NpgsqlDbType.Varchar, 50);
      New_Customer.Parameters.Add("age_in", NpgsqlDbType.Smallint);
      New_Customer.Parameters.Add("income_in", NpgsqlDbType.Integer);
      New_Customer.Parameters.Add("gender_in", NpgsqlDbType.Varchar, 1);
      New_Customer.Parameters.Add("customerid_out", NpgsqlDbType.Integer).Direction = ParameterDirection.Output;
      New_Customer.Parameters.Add("username_out", NpgsqlDbType.Varchar, 50).Direction = ParameterDirection.Output;

      New_Member = new NpgsqlCommand("NEW_MEMBER" + target_store_number, objConn);
      New_Member.CommandType = CommandType.StoredProcedure;
      New_Member.Parameters.Add("customerid_in", NpgsqlDbType.Integer);
      New_Member.Parameters.Add("membershiplevel_in", NpgsqlDbType.Integer);

      Get_Membership_Status = new NpgsqlCommand("GET_MEMBERSHIP_STATUS" + target_store_number, objConn);
      Get_Membership_Status.CommandType = CommandType.StoredProcedure;
      Get_Membership_Status.Parameters.Add("customerid_in", NpgsqlDbType.Integer);

      Renew_Membership = new NpgsqlCommand("RENEW_MEMBERSHIP" + target_store_number, objConn);
      Renew_Membership.CommandType = CommandType.StoredProcedure;
      Renew_Membership.Parameters.Add("customerid_in", NpgsqlDbType.Integer);

      New_Prod_Review = new NpgsqlCommand("NEW_PROD_REVIEW" + target_store_number, objConn);
      New_Prod_Review.CommandType = CommandType.StoredProcedure;
      New_Prod_Review.Parameters.Add("prod_id_in", NpgsqlDbType.Integer);
      New_Prod_Review.Parameters.Add("stars_in", NpgsqlDbType.Integer);
      New_Prod_Review.Parameters.Add("customerid_in", NpgsqlDbType.Integer);
      New_Prod_Review.Parameters.Add("review_summary_in", NpgsqlDbType.Varchar, 50);
      New_Prod_Review.Parameters.Add("review_text_in", NpgsqlDbType.Varchar, 1000);

      New_Review_Helpfulness = new NpgsqlCommand("NEW_REVIEW_HELPFULNESS" + target_store_number, objConn);
      New_Review_Helpfulness.CommandType = CommandType.StoredProcedure;
      New_Review_Helpfulness.Parameters.Add("review_id_in", NpgsqlDbType.Integer);
      New_Review_Helpfulness.Parameters.Add("customerid_in", NpgsqlDbType.Integer);
      New_Review_Helpfulness.Parameters.Add("review_helpfulness_in", NpgsqlDbType.Integer);

      Browse_By_Category = new NpgsqlCommand("BROWSE_BY_CATEGORY" + target_store_number, objConn);
      Browse_By_Category.CommandType = CommandType.StoredProcedure;
      Browse_By_Category.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Browse_By_Category.Parameters.Add("category_in", NpgsqlDbType.Integer);
      Browse_By_Category.Parameters.Add("special_in", NpgsqlDbType.Integer);

      Browse_By_Actor = new NpgsqlCommand("BROWSE_BY_ACTOR" + target_store_number, objConn);
      Browse_By_Actor.CommandType = CommandType.StoredProcedure;
      Browse_By_Actor.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Browse_By_Actor.Parameters.Add("actor_in", NpgsqlDbType.Varchar, 50);

      Browse_By_Title = new NpgsqlCommand("BROWSE_BY_TITLE" + target_store_number, objConn);
      Browse_By_Title.CommandType = CommandType.StoredProcedure;
      Browse_By_Title.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Browse_By_Title.Parameters.Add("title_in", NpgsqlDbType.Varchar, 50);

      Browse_By_Membership = new NpgsqlCommand("BROWSE_BY_MEMBERSHIP" + target_store_number, objConn);
      Browse_By_Membership.CommandType = CommandType.StoredProcedure;
      Browse_By_Membership.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Browse_By_Membership.Parameters.Add("membershiptype_in", NpgsqlDbType.Integer);

      Get_Prod_Reviews = new NpgsqlCommand("GET_PROD_REVIEWS" + target_store_number, objConn);
      Get_Prod_Reviews.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews.Parameters.Add("prod_in", NpgsqlDbType.Integer);

      Get_Prod_Reviews_By_Date = new NpgsqlCommand("GET_PROD_REVIEWS_BY_DATE" + target_store_number, objConn);
      Get_Prod_Reviews_By_Date.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Date.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews_By_Date.Parameters.Add("prod_in", NpgsqlDbType.Integer);

      Get_Prod_Reviews_By_Stars = new NpgsqlCommand("GET_PROD_REVIEWS_BY_STARS" + target_store_number, objConn);
      Get_Prod_Reviews_By_Stars.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Stars.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews_By_Stars.Parameters.Add("prod_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews_By_Stars.Parameters.Add("stars_in", NpgsqlDbType.Integer);

      Get_Prod_Reviews_By_Title = new NpgsqlCommand("GET_PROD_REVIEWS_BY_TITLE" + target_store_number, objConn);
      Get_Prod_Reviews_By_Title.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Title.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews_By_Title.Parameters.Add("search_depth_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews_By_Title.Parameters.Add("title_in", NpgsqlDbType.Varchar, 50);

      Get_Prod_Reviews_By_Actor = new NpgsqlCommand("GET_PROD_REVIEWS_BY_ACTOR" + target_store_number, objConn);
      Get_Prod_Reviews_By_Actor.CommandType = CommandType.StoredProcedure;
      Get_Prod_Reviews_By_Actor.Parameters.Add("batch_size_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews_By_Actor.Parameters.Add("search_depth_in", NpgsqlDbType.Integer);
      Get_Prod_Reviews_By_Actor.Parameters.Add("actor_in", NpgsqlDbType.Varchar, 50);

      // Purchase - array-based, unlimited items
      Purchase = new NpgsqlCommand("PURCHASE" + target_store_number, objConn);
      Purchase.CommandType = CommandType.StoredProcedure;
      Purchase.Parameters.Add("customerid_in", NpgsqlDbType.Integer);
      Purchase.Parameters.Add("netamount_in", NpgsqlDbType.Numeric);
      Purchase.Parameters.Add("taxamount_in", NpgsqlDbType.Numeric);
      Purchase.Parameters.Add("totalamount_in", NpgsqlDbType.Numeric);
      Purchase.Parameters.Add("prod_ids", NpgsqlDbType.Array | NpgsqlDbType.Integer);
      Purchase.Parameters.Add("qtys", NpgsqlDbType.Array | NpgsqlDbType.Integer);

      //New Product
      New_Product = new NpgsqlCommand("addnewinventoryproduct" + target_store_number, objConn);
      New_Product.CommandType = CommandType.StoredProcedure;
      New_Product.Parameters.Add("p_cat", NpgsqlDbType.Smallint);
      New_Product.Parameters.Add("p_title", NpgsqlDbType.Varchar);
      New_Product.Parameters.Add("p_actor", NpgsqlDbType.Varchar);
      New_Product.Parameters.Add("p_price", NpgsqlDbType.Numeric);
      New_Product.Parameters.Add("p_stock", NpgsqlDbType.Integer);
      var outParam = new NpgsqlParameter("v_new_id", DbType.Int32)
      {
        Direction = ParameterDirection.Output
      };
      New_Product.Parameters.Add(outParam);

      // Pre-compile cost query commands for cart sizes 1-10
      for (int items = 1; items <= 100; items++)
      {
        string query = "SELECT PROD_ID, PRICE FROM PRODUCTS" + target_store_number + " WHERE PROD_ID IN (";
        for (int i = 0; i < items; i++)
        {
          if (i > 0)
            query += ",";
          query += "@ARG" + i;
        }
        query += ")";
        CostQuery[items] = new NpgsqlCommand(query, objConn);
        for (int i = 0; i < items; i++)
        {
          CostQuery[items].Parameters.Add("@ARG" + i, NpgsqlDbType.Integer);
        }
      }

      // Manager thread stored procedures (PostgreSQL uses function calls)
      Remove_Review_By_Product = new NpgsqlCommand("SELECT deleted_review_id FROM removereviewbyproduct" + target_store_number + "(@p_prod_id)", objConn);
      Remove_Review_By_Product.Parameters.Add("p_prod_id", NpgsqlDbType.Integer);

      Remove_Unhelpful_Reviews = new NpgsqlCommand("SELECT rows_deleted FROM removeunhelpfulreviews" + target_store_number + "(@p_batch_size)", objConn);
      Remove_Unhelpful_Reviews.Parameters.Add("p_batch_size", NpgsqlDbType.Integer);

      Remove_Reviews_By_Date = new NpgsqlCommand("SELECT rows_deleted FROM removereviewsbydate" + target_store_number + "(@p_batch_size)", objConn);
      Remove_Reviews_By_Date.Parameters.Add("p_batch_size", NpgsqlDbType.Integer);

      Adjust_Prices = new NpgsqlCommand("SELECT rows_updated FROM adjustprices" + target_store_number + "(@p_prod_id)", objConn);
      Adjust_Prices.Parameters.Add("p_prod_id", NpgsqlDbType.Integer);

      Bulk_Price_Adjustment = new NpgsqlCommand("SELECT rows_updated FROM bulkpriceadjustment" + target_store_number + "(@p_batch_size, @p_category)", objConn);
      Bulk_Price_Adjustment.Parameters.Add("p_batch_size", NpgsqlDbType.Integer);
      Bulk_Price_Adjustment.Parameters.Add("p_category", NpgsqlDbType.Integer);

      Mark_Specials = new NpgsqlCommand("SELECT rows_updated FROM markspecials" + target_store_number + "(@p_prod_id)", objConn);
      Mark_Specials.Parameters.Add("p_prod_id", NpgsqlDbType.Integer);

      Expire_Memberships = new NpgsqlCommand("SELECT rows_deleted FROM expirememberships" + target_store_number + "(@p_batch_size)", objConn);
      Expire_Memberships.Parameters.Add("p_batch_size", NpgsqlDbType.Integer);

      Purge_Old_Orders = new NpgsqlCommand("SELECT rows_deleted FROM purge_old_orders" + target_store_number + "(@p_batch_size)", objConn);
      Purge_Old_Orders.Parameters.Add("p_batch_size", NpgsqlDbType.Integer);

      Upgrade_Membership = new NpgsqlCommand("SELECT rows_upgraded FROM upgrade_membership" + target_store_number + "(@p_batch_size)", objConn);
      Upgrade_Membership.Parameters.Add("p_batch_size", NpgsqlDbType.Integer);

      Promotional_Membership = new NpgsqlCommand("SELECT promotionalmembership" + target_store_number + "(@p_batch_size)", objConn);
      Promotional_Membership.Parameters.Add("p_batch_size", NpgsqlDbType.Integer);

      Get_Membership_Analytics = new NpgsqlCommand("SELECT * FROM getmembershipanalytics" + target_store_number + "()", objConn);

      Get_New_Customer_Analytics = new NpgsqlCommand("SELECT * FROM getnewcustomeranalytics" + target_store_number + "(@customers_baseline)", objConn);
      Get_New_Customer_Analytics.Parameters.Add("customers_baseline", NpgsqlDbType.Bigint);

      Get_Review_Analytics = new NpgsqlCommand("SELECT * FROM getreviewanalytics" + target_store_number + "(@reviewid_baseline)", objConn);
      Get_Review_Analytics.Parameters.Add("reviewid_baseline", NpgsqlDbType.Bigint);

      Get_Price_Point_Analytics = new NpgsqlCommand("SELECT * FROM getpricepointanalytics" + target_store_number + "(@baseline_product_count)", objConn);
      Get_Price_Point_Analytics.Parameters.Add("baseline_product_count", NpgsqlDbType.Bigint);

      Get_Inventory_Analytics = new NpgsqlCommand("SELECT * FROM getinventoryanalytics" + target_store_number + "()", objConn);
    }

    //
    //-------------------------------------------------------------------------------------------------
    //  
    public bool ds2connect()
    {
      // Add Password=xxx to sConnectionString if password is set
      //Changed by GSK (added new user ds2user and new server to connect everytime)
      //MaxPoolSize, Timeout, and CommandTimeout values increased for support at higher load levels
      try
      {
        objConn.Open();
      }
      catch (PostgresException e)
      {
        //Console.WriteLine("Thread {0}: error in connecting to database {1}: {2}",  Thread.CurrentThread.Name,
        //  Controller.target, e.Message);
        //Changed by GSK
        Console.WriteLine("Thread {0}: error in connecting to database {1}: {2}", Thread.CurrentThread.Name,
        target_server, e.Message);
        return (false);
      }

      return (true);
    } // end ds2connect()

    //
    //-------------------------------------------------------------------------------------------------
    // 
    public bool ds2login(string username_in, string password_in, ref int customerid_out, ref int rows_returned,
      ref string[] title_out, ref string[] actor_out, ref string[] related_title_out, ref double rt)
    {
      Login.Parameters["username_in"].Value = username_in;
      Login.Parameters["password_in"].Value = password_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        using (NpgsqlDataReader Rdr = Login.ExecuteReader())
        {
          int i_row = 0;
          while (Rdr.Read())
          {
            customerid_out = (int)Rdr[0];
            title_out[i_row] = Rdr.GetString(1);
            actor_out[i_row] = Rdr.GetString(2);
            related_title_out[i_row] = Rdr.GetString(3);
            //Console.WriteLine("customerid_out: {0} title: {1} actor: {2} related: {3}", customerid_out, title_out[i_row], actor_out[i_row], related_title_out[i_row]);
            ++i_row;
          }
          rows_returned = i_row;
        }
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: Error in Login: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }  // end ds2login
       //
       //-------------------------------------------------------------------------------------------------
       // 
    public bool ds2newcustomer(string password_in, string firstname_in,
      string lastname_in, string address1_in, string address2_in, string city_in, string state_in,
      string zip_in, string country_in, string email_in, string phone_in, int creditcardtype_in,
      string creditcard_in, int ccexpmon_in, int ccexpyr_in, int age_in, int income_in,
      string gender_in, ref string username_out, ref int customerid_out, ref double rt)
    {
      int region_in = (country_in == "US") ? 1 : 2;
      string creditcardexpiration_in = String.Format("{0:D4}/{1:D2}", ccexpyr_in, ccexpmon_in);

      New_Customer.Parameters["firstname_in"].Value = firstname_in;
      New_Customer.Parameters["lastname_in"].Value = lastname_in;
      New_Customer.Parameters["address1_in"].Value = address1_in;
      New_Customer.Parameters["address2_in"].Value = address2_in;
      New_Customer.Parameters["city_in"].Value = city_in;
      New_Customer.Parameters["state_in"].Value = state_in;
      New_Customer.Parameters["zip_in"].Value = zip_in;
      New_Customer.Parameters["country_in"].Value = country_in;
      New_Customer.Parameters["region_in"].Value = region_in;
      New_Customer.Parameters["email_in"].Value = email_in;
      New_Customer.Parameters["phone_in"].Value = phone_in;
      New_Customer.Parameters["creditcardtype_in"].Value = creditcardtype_in;
      New_Customer.Parameters["creditcard_in"].Value = creditcard_in;
      New_Customer.Parameters["creditcardexpiration_in"].Value = creditcardexpiration_in;
      New_Customer.Parameters["password_in"].Value = password_in;
      New_Customer.Parameters["age_in"].Value = age_in;
      New_Customer.Parameters["income_in"].Value = income_in;
      New_Customer.Parameters["gender_in"].Value = gender_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        New_Customer.ExecuteNonQuery();
        customerid_out = Convert.ToInt32(New_Customer.Parameters["customerid_out"].Value);
        username_out = New_Customer.Parameters["username_out"].Value.ToString();
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: SQL Error {1} in New_Customer: {2}",
          Thread.CurrentThread.Name, e.SqlState, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2newcustomer()

    //
    //-------------------------------------------------------------------------------------------------
    // 
    public bool ds2newmember(int customerid_in, int membershiplevel_in, ref double rt)
    {
      New_Member.Parameters["customerid_in"].Value = customerid_in;
      New_Member.Parameters["membershiplevel_in"].Value = membershiplevel_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = New_Member.ExecuteScalar();

        // If stored procedure returns NULL (customer already has membership or doesn't exist), return false
        if (result == null || result == DBNull.Value || Convert.ToInt32(result) == 0)
        {
          return false;
        }

        //    Console.WriteLine("Thread {0}: New_Member created w/customerid_in= {1}  membershiplevel_in={2}",
        //      Thread.CurrentThread.Name, customerid_in, membershiplevel_in);

        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: postgreSQL Error in New_Member.ExecuteScalar(): {2}",
          Thread.CurrentThread.Name, e.SqlState, e.Message);
        return false;
      }
      catch (System.Exception e)
      {
        Console.WriteLine("Thread {0}: System Error in New_Member.ExecuteScalar(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2newmember()

    //
    //-------------------------------------------------------------------------------------------------
    //
    public bool ds2getmembershipstatus(int customerid_in, ref int membership_level_out, ref int is_expired_out, ref double rt)
    {
      Get_Membership_Status.Parameters["customerid_in"].Value = customerid_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        using (NpgsqlDataReader reader = Get_Membership_Status.ExecuteReader())
        {
          if (reader.Read())
          {
            membership_level_out = reader.GetInt32(0);
            is_expired_out = reader.GetInt32(1);
          }
          else
          {
            membership_level_out = 0;
            is_expired_out = 0;
          }
        }
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: PostgreSQL Error in Get_Membership_Status.ExecuteReader(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      catch (System.Exception e)
      {
        Console.WriteLine("Thread {0}: System Error in Get_Membership_Status.ExecuteReader(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2getmembershipstatus()

    //
    //-------------------------------------------------------------------------------------------------
    //
    public bool ds2renewmembership(int customerid_in, ref int rows_affected_out, ref double rt)
    {
      Renew_Membership.Parameters["customerid_in"].Value = customerid_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        rows_affected_out = Convert.ToInt32(Renew_Membership.ExecuteScalar().ToString());
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: PostgreSQL Error in Renew_Membership.ExecuteScalar(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      catch (System.Exception e)
      {
        Console.WriteLine("Thread {0}: System Error in Renew_Membership.ExecuteScalar(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2renewmembership()


    //
    //-------------------------------------------------------------------------------------------------
    //
    public bool ds2browse(string browse_type_in, string browse_category_in, string browse_actor_in,
      string browse_title_in, int batch_size_in, int search_depth_in, int customerid_out, int membership_level_in, ref int rows_returned,
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref decimal[] price_out,
      ref int[] special_out, ref int[] common_prod_id_out, ref double rt)
    {
      // Products table: PROD_ID INT, CATEGORY TINYINT, TITLE VARCHAR(50), ACTOR VARCHAR(50),
      //   PRICE DECIMAL(12,2), SPECIAL TINYINT, COMMON_PROD_ID INT
      string data_in = string.Empty;
      int[] category_out = new int[GlobalConstants.MAX_ROWS];
      int membership_item = 0, special = 0;

      // Search for special half the time
      if (Random.Shared.Next(100) < 50)
      {
        special = 1;
      }

      switch (browse_type_in)
      {
        case "category":
          Browse_By_Category.Parameters["batch_size_in"].Value = batch_size_in;
          Browse_By_Category.Parameters["category_in"].Value = Convert.ToInt32(browse_category_in);
          Browse_By_Category.Parameters["special_in"].Value = special;
          data_in = browse_category_in;
          break;
        case "actor":
          Browse_By_Actor.Parameters["batch_size_in"].Value = batch_size_in;
          Browse_By_Actor.Parameters["actor_in"].Value = "\"" + browse_actor_in + "\"";
          data_in = "\"" + browse_actor_in + "\"";
          break;
        case "title":
          Browse_By_Title.Parameters["batch_size_in"].Value = batch_size_in;
          Browse_By_Title.Parameters["title_in"].Value = "\"" + browse_title_in + "\"";
          data_in = "\"" + browse_title_in + "\"";
          break;
        case "membership":
          Browse_By_Membership.Parameters["batch_size_in"].Value = batch_size_in;
          Browse_By_Membership.Parameters["membershiptype_in"].Value = membership_level_in;
          data_in = "membership item: " + membership_level_in;
          break;
        default:
          Console.WriteLine("  Browse type '{0}' unsupported.", browse_type_in);
          rows_returned = -1;
          return false;
      }

      //    Console.WriteLine("Thread {0}: Calling Browse w/ browse_type= {1} batch_size_in= {2}  data_in= {3}",
      //      Thread.CurrentThread.Name, browse_type_in, batch_size_in, data_in);

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        NpgsqlDataReader Rdr;
        switch (browse_type_in)
        {
          case "category":
            Rdr = Browse_By_Category.ExecuteReader();
            break;
          case "actor":
            Rdr = Browse_By_Actor.ExecuteReader();
            break;
          case "membership":
            Rdr = Browse_By_Membership.ExecuteReader();
            break;
          default:
          case "title":
            Rdr = Browse_By_Title.ExecuteReader();
            break;
        }

        using (Rdr)
        {
          int i_row = 0;
          while (Rdr.Read())
          {
            prod_id_out[i_row] = Rdr.GetInt32(0);
            category_out[i_row] = Rdr.GetInt16(1);
            title_out[i_row] = Rdr.GetString(2);
            actor_out[i_row] = Rdr.GetString(3);
            price_out[i_row] = Rdr.GetDecimal(4);
            special_out[i_row] = Rdr.GetInt16(5);
            common_prod_id_out[i_row] = Rdr.GetInt32(6);
            membership_item = Rdr.GetInt32(7);
            //Console.WriteLine("\tprod_id_out: {0} category_out: {1} title_out: {2} actor_out: {3} price_out: {4} special_out: {5} common_prod_id_out: {6} membership_item: {7}",prod_id_out[i_row],category_out[i_row],title_out[i_row],actor_out[i_row],price_out[i_row], special_out[i_row],common_prod_id_out[i_row], membership_item);
            ++i_row;
          }
          rows_returned = i_row;
        }
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: Error in Browse: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2browse()

    //
    //-------------------------------------------------------------------------------------------------
    // 

    public bool ds2browsereview(string browse_review_type_in, string get_review_category_in, string get_review_actor_in,
      string get_review_title_in, int batch_size_in, int search_depth_in, int customerid_out, ref int rows_returned,
      ref int[] prod_id_out, ref string[] title_out, ref string[] actor_out, ref int[] review_id_out,
      ref string[] review_date_out, ref int[] review_stars_out, ref int[] review_customerid_out,
      ref string[] review_summary_out, ref string[] review_text_out, ref int[] review_helpfulness_sum_out, ref double rt)
    {
      // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
      // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte)
      string data_in = null;

      switch (browse_review_type_in)
      {
        case "actor":
          Get_Prod_Reviews_By_Actor.Parameters["batch_size_in"].Value = batch_size_in;
          Get_Prod_Reviews_By_Actor.Parameters["search_depth_in"].Value = search_depth_in;
          Get_Prod_Reviews_By_Actor.Parameters["actor_in"].Value = "\"" + get_review_actor_in + "\"";
          data_in = "\"" + get_review_actor_in + "\"";
          break;
        case "title":
          Get_Prod_Reviews_By_Title.Parameters["batch_size_in"].Value = batch_size_in;
          Get_Prod_Reviews_By_Title.Parameters["search_depth_in"].Value = search_depth_in;
          Get_Prod_Reviews_By_Title.Parameters["title_in"].Value = "\"" + get_review_title_in + "\"";
          data_in = "\"" + get_review_title_in + "\"";
          break;
      }

      //    Console.WriteLine("Thread {0}: Calling Browse w/ browse_type= {1}  batch_size_in= {2}  data_in= {3}",
      //      Thread.CurrentThread.Name, browse_type_in, batch_size_in, data_in);

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        NpgsqlDataReader Rdr;
        switch (browse_review_type_in)
        {
          case "actor":
            Rdr = Get_Prod_Reviews_By_Actor.ExecuteReader();
            break;
          default:
          case "title":
            Rdr = Get_Prod_Reviews_By_Title.ExecuteReader();
            break;
        }

        using (Rdr)
        {
          int i_row = 0;
          while (Rdr.Read())
          {
            prod_id_out[i_row] = Rdr.GetInt32(0);
            title_out[i_row] = Rdr.GetString(1);
            actor_out[i_row] = Rdr.GetString(2);
            review_id_out[i_row] = Rdr.GetInt32(3);
            review_date_out[i_row] = Convert.ToString(Rdr.GetDateTime(4));
            review_stars_out[i_row] = Rdr.GetInt32(5);
            review_customerid_out[i_row] = Rdr.GetInt32(6);
            review_summary_out[i_row] = Rdr.GetString(7);
            review_text_out[i_row] = Rdr.GetString(8);
            review_helpfulness_sum_out[i_row] = Rdr.GetInt32(9);
            //Console.WriteLine("\tprod_id_out: {0} title_out: {1} actor_out: {2} review_id_out: {3} review_date_out: {4} review_stars_out: {5} review_customerid_out: {6} review_summary_out: {7}\n\treview_text_out: {8} review_helpfulness_sum_out: {9}\n", prod_id_out[i_row], title_out[i_row], actor_out[i_row], review_id_out[i_row], review_date_out[i_row], review_stars_out[i_row], review_customerid_out[i_row], review_summary_out[i_row], review_text_out[i_row], review_helpfulness_sum_out[i_row] );
            ++i_row;
          }
          rows_returned = i_row;
        }
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: postgreSQL Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      catch (System.Exception e)
      {
        Console.WriteLine("Thread {0}: System Error in Browse Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2browsereview()

    //
    //-------------------------------------------------------------------------------------------------
    // 

    public bool ds2getreview(string get_review_type_in, int get_review_prod_in, int get_review_stars_in, int customerid_out, int batch_size_in, ref int rows_returned,
      ref int[] prod_id_out, ref int[] review_id_out, ref string[] review_date_out, ref int[] review_stars_out, ref int[] review_customerid_out,
      ref string[] review_summary_out, ref string[] review_text_out, ref int[] review_helpfulness_sum_out, ref double rt)
    {
      // Reviews Table: "REVIEW_ID" NUMBER,  "PROD_ID" NUMBER,  "REVIEW_DATE" DATE, "STARS" NUMBER,
      // "CUSTOMERID" NUMBER,  "REVIEW_SUMMARY" VARCHAR2(50 byte), "REVIEW_TEXT" VARCHAR2(1000 byte)
      //string data_in = null;

      switch (get_review_type_in)
      {
        case "noorder":
          Get_Prod_Reviews.Parameters["batch_size_in"].Value = batch_size_in;
          Get_Prod_Reviews.Parameters["prod_in"].Value = get_review_prod_in;
          break;
        case "star":
          Get_Prod_Reviews_By_Stars.Parameters["batch_size_in"].Value = batch_size_in;
          Get_Prod_Reviews_By_Stars.Parameters["prod_in"].Value = get_review_prod_in;
          Get_Prod_Reviews_By_Stars.Parameters["stars_in"].Value = get_review_stars_in;
          break;
        case "date":
          Get_Prod_Reviews_By_Date.Parameters["batch_size_in"].Value = batch_size_in;
          Get_Prod_Reviews_By_Date.Parameters["prod_in"].Value = get_review_prod_in;
          break;
      }

      //    Console.WriteLine("Thread {0}: Calling Browse w/ browse_type= {1}  batch_size_in= {2}  data_in= {3}",
      //      Thread.CurrentThread.Name, browse_type_in, batch_size_in, data_in);

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        NpgsqlDataReader Rdr;
        switch (get_review_type_in)
        {
          default:
          case "noorder":
            Rdr = Get_Prod_Reviews.ExecuteReader();
            break;
          case "star":
            Rdr = Get_Prod_Reviews_By_Stars.ExecuteReader();
            break;
          case "date":
            Rdr = Get_Prod_Reviews_By_Date.ExecuteReader();
            break;
        }

        using (Rdr)
        {
          int i_row = 0;
          while (Rdr.Read())
          {
            review_id_out[i_row] = Rdr.GetInt32(0);
            prod_id_out[i_row] = Rdr.GetInt32(1);
            review_date_out[i_row] = Convert.ToString(Rdr.GetDateTime(2));
            review_stars_out[i_row] = Rdr.GetInt32(3);
            review_customerid_out[i_row] = Rdr.GetInt32(4);
            review_summary_out[i_row] = Rdr.GetString(5);
            review_text_out[i_row] = Rdr.GetString(6);
            review_helpfulness_sum_out[i_row] = Rdr.GetInt32(7);
            //Console.WriteLine("\treview_id_out: {0} prod_id_out: {1} review_date_out: {2} review_stars_out: {3} review_customerid_out: {4} review_summary_out: {5} review_text_out: {6} review_helpfulness_sum_out: {7}",
            //  review_id_out[i_row], prod_id_out[i_row], review_date_out[i_row], review_stars_out[i_row], review_customerid_out[i_row], review_summary_out[i_row], review_text_out[i_row], review_helpfulness_sum_out[i_row]);
            ++i_row;
          }
          rows_returned = i_row;
        }
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: postgreSQL Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      catch (System.Exception e)
      {
        Console.WriteLine("Thread {0}: System Error in Get Product Reviews: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2getreview()

    //
    //-------------------------------------------------------------------------------------------------
    // 
    public bool ds2newreview(int new_review_prod_id_in, int new_review_stars_in, int new_review_customerid_in,
            string new_review_summary_in, string new_review_text_in, ref int newreviewid_out, ref double rt)
    {
      New_Prod_Review.Parameters["prod_id_in"].Value = new_review_prod_id_in;
      New_Prod_Review.Parameters["stars_in"].Value = new_review_stars_in;
      New_Prod_Review.Parameters["customerid_in"].Value = new_review_customerid_in;
      New_Prod_Review.Parameters["review_summary_in"].Value = new_review_summary_in;
      New_Prod_Review.Parameters["review_text_in"].Value = new_review_text_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        newreviewid_out = Convert.ToInt32(New_Prod_Review.ExecuteScalar().ToString(), 10);
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: Sql Server Error in New_Prod_Review.ExecuteScalar(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      catch (System.Exception e)
      {
        Console.WriteLine("Thread {0}: System Error in New_Prod_Review.ExecuteNonQuery(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2newreview()

    //
    //-------------------------------------------------------------------------------------------------
    // 
    public bool ds2newreviewhelpfulness(int reviewid_in, int customerid_in, int reviewhelpfulness_in, ref int reviewhelpfulnessid_out, ref double rt)
    {
      New_Review_Helpfulness.Parameters["review_id_in"].Value = reviewid_in;
      New_Review_Helpfulness.Parameters["customerid_in"].Value = customerid_in;
      New_Review_Helpfulness.Parameters["review_helpfulness_in"].Value = reviewhelpfulness_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        reviewhelpfulnessid_out = Convert.ToInt32(New_Review_Helpfulness.ExecuteScalar().ToString(), 10);
        return true;
      }
      catch (PostgresException e)
      {
        // SqlState 23503: FK violation (review was deleted by manager between browse and rating)
        if (e.SqlState == "23503")
        {
          Console.WriteLine("Thread {0}: Review {1} no longer exists (deleted by manager), skipping helpfulness rating",
            Thread.CurrentThread.Name, reviewid_in);
          reviewhelpfulnessid_out = 0;
          return true;  // Return success to avoid retries
        }

        // SqlState 40P01: Deadlock - return false to trigger retry
        // All other errors - log and return false
        Console.WriteLine("Thread {0}: postgreSQL error in New_Review_Helpfulness.ExecuteScalar(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      catch (System.Exception e)
      {
        Console.WriteLine("Thread {0}: System Error in New_Review_Helpfulness.ExecuteScalar(): {1}",
          Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2newreviewhelpfulness()

    //
    //-------------------------------------------------------------------------------------------------
    //
    public bool ds2purchase(int cart_items, int[] prod_id_in, int[] qty_in, int customerid_out,
      ref int neworderid_out, ref bool IsRollback, ref double rt)
    {
      int i, j;

      // No item limit with array parameter approach!

      // Extra, non-stored procedure query to find total cost of purchase
      Decimal netamount_in = 0;

      // Use pre-compiled cost query command (still limited to 10 by CostQuery array size)
      // For cart_items > 10, fall back to dynamic query
      if (cart_items <= 100)
      {
        var cost_command = CostQuery[cart_items];
        for (i = 0; i < cart_items; i++)
        {
          cost_command.Parameters["@ARG" + i].Value = prod_id_in[i];
        }

        using (NpgsqlDataReader Rdr = cost_command.ExecuteReader())
        {
          while (Rdr.Read())
          {
            j = 0;
            int prod_id = Rdr.GetInt32(0);
            while (prod_id_in[j] != prod_id)
              ++j; // Find which product was returned
            netamount_in = netamount_in + qty_in[j] * Rdr.GetDecimal(1);
          }
        }
      }
      else
      {
        // Fallback: build dynamic query for carts > 100 items
        string cost_query = "SELECT PROD_ID, PRICE FROM PRODUCTS" + target_store_number + " WHERE PROD_ID IN (" + prod_id_in[0];
        for (i = 1; i < cart_items; i++)
          cost_query = cost_query + "," + prod_id_in[i];
        cost_query = cost_query + ")";

        NpgsqlCommand cost_command = new NpgsqlCommand(cost_query, objConn);
        using (NpgsqlDataReader Rdr = cost_command.ExecuteReader())
        {
          while (Rdr.Read())
          {
            j = 0;
            int prod_id = Rdr.GetInt32(0);
            while (prod_id_in[j] != prod_id)
              ++j;
            netamount_in = netamount_in + qty_in[j] * Rdr.GetDecimal(1);
          }
        }
      }

      Decimal taxamount_in = (Decimal)0.0825 * netamount_in;
      Decimal totalamount_in = netamount_in + taxamount_in;

      // Sort products by prod_id to prevent deadlocks (consistent lock ordering)
      Array.Sort(prod_id_in, qty_in, 0, cart_items);

      // Build arrays for PostgreSQL array parameters
      int[] prod_ids = new int[cart_items];
      int[] qtys = new int[cart_items];
      Array.Copy(prod_id_in, prod_ids, cart_items);
      Array.Copy(qty_in, qtys, cart_items);

      Purchase.Parameters["customerid_in"].Value = customerid_out;
      Purchase.Parameters["netamount_in"].Value = netamount_in;
      Purchase.Parameters["taxamount_in"].Value = taxamount_in;
      Purchase.Parameters["totalamount_in"].Value = totalamount_in;
      Purchase.Parameters["prod_ids"].Value = prod_ids;
      Purchase.Parameters["qtys"].Value = qtys;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        neworderid_out = (int)Purchase.ExecuteScalar();

        if (neworderid_out == 0)
          IsRollback = true;
        return true;
      }
      catch (PostgresException e)
      {
        if (e.SqlState == "P0001")
        {
          neworderid_out = 0;
          return true;
        }
        else
        {
          Console.WriteLine("Thread {0}: SQL Error {1} in Purchase: {2}",
            Thread.CurrentThread.Name, e.SqlState, e.Message);
          return false;
        }
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    } // end ds2purchase()

    //
    //-------------------------------------------------------------------------------------------------
    //
    public bool ds2newproduct(int new_category_in, string new_title_in, string new_actor_in, decimal new_price_in, int new_stock_in, ref int newproduct_id, ref double rt)
    {
      New_Product.Parameters["p_cat"].Value = new_category_in;
      New_Product.Parameters["p_title"].Value = new_title_in;
      New_Product.Parameters["p_actor"].Value = new_actor_in;
      New_Product.Parameters["p_price"].Value = new_price_in;
      New_Product.Parameters["p_stock"].Value = new_stock_in;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        New_Product.ExecuteNonQuery();
        newproduct_id = Convert.ToInt32(New_Product.Parameters["v_new_id"].Value.ToString());
        return true;
      }
      catch (PostgresException e)
      {
        Console.WriteLine("Thread {0}: postgreSQL Error in New_Product: {1}", Thread.CurrentThread.Name, e.Message);
        return false;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }
    //
    //-------------------------------------------------------------------------------------------------
    // Manager Thread Methods
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36removereviewbyproduct(int prodId, ref double rt)
    {
      Remove_Review_By_Product.Parameters["p_prod_id"].Value = prodId;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Remove_Review_By_Product.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36removereviewbyproduct error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36removeunhelpfulreviews(int batchSize, ref double rt)
    {
      Remove_Unhelpful_Reviews.Parameters["p_batch_size"].Value = batchSize;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Remove_Unhelpful_Reviews.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36removeunhelpfulreviews error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36removereviewsbydate(int batchSize, ref double rt)
    {
      Remove_Reviews_By_Date.Parameters["p_batch_size"].Value = batchSize;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Remove_Reviews_By_Date.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36removereviewsbydate error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36adjustprices(int prodId, ref double rt)
    {
      Adjust_Prices.Parameters["p_prod_id"].Value = prodId;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Adjust_Prices.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36adjustprices error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36bulkpriceadjustment(int batchSize, int category, ref double rt)
    {
      Bulk_Price_Adjustment.Parameters["p_batch_size"].Value = batchSize;
      Bulk_Price_Adjustment.Parameters["p_category"].Value = category;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Bulk_Price_Adjustment.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36bulkpriceadjustment error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36markspecials(int prodId, ref double rt)
    {
      Mark_Specials.Parameters["p_prod_id"].Value = prodId;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Mark_Specials.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36markspecials error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36expirememberships(int batchSize, ref double rt)
    {
      Expire_Memberships.Parameters["p_batch_size"].Value = batchSize;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Expire_Memberships.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36expirememberships error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public int ds36purgeoldorders(int batchSize, ref double rt)
    {
      Purge_Old_Orders.Parameters["p_batch_size"].Value = batchSize;

      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        object result = Purge_Old_Orders.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36purgeoldorders error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    public int ds36upgrademembership(int batchSize, ref double rt)
    {
      Upgrade_Membership.Parameters["p_batch_size"].Value = batchSize;

      Stopwatch timer = Stopwatch.StartNew();
      try
      {
        object result = Upgrade_Membership.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36upgrademembership error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    public int ds36promotionalmembership(int batchSize, ref double rt)
    {
      Promotional_Membership.Parameters["p_batch_size"].Value = batchSize;

      Stopwatch timer = Stopwatch.StartNew();
      try
      {
        object result = Promotional_Membership.ExecuteScalar();
        return result != null && result != DBNull.Value ? Convert.ToInt32(result) : 0;
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36promotionalmembership error: {e.Message}");
        return 0;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
    }

    public List<MembershipAnalyticsRow> ds36getmembershipanalytics(ref double rt)
    {
      var results = new List<MembershipAnalyticsRow>();
      Stopwatch timer = Stopwatch.StartNew();
      try
      {
        using (NpgsqlDataReader reader = Get_Membership_Analytics.ExecuteReader())
        {
          while (reader.Read())
          {
            results.Add(new MembershipAnalyticsRow
            {
              MembershipType = reader.IsDBNull(0) ? (int?)null : reader.GetInt32(0),
              ActiveMemberCount = reader.GetInt64(1),
              ExpiredMemberCount = reader.GetInt64(2),
              TotalOrders = reader.GetInt64(3),
              TotalRevenue = reader.GetDecimal(4)
            });
          }
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36getmembershipanalytics error: {e.Message}");
        throw;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }
      return results;
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public NewCustomerAnalyticsRow ds36getnewcustomeranalytics(long customers_baseline, ref double rt)
    {
      NewCustomerAnalyticsRow result = null;
      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        Get_New_Customer_Analytics.Parameters["customers_baseline"].Value = customers_baseline;

        using (NpgsqlDataReader reader = Get_New_Customer_Analytics.ExecuteReader())
        {
          if (reader.Read())
          {
            result = new NewCustomerAnalyticsRow
            {
              Created = reader.GetInt64(0),
              TwoPlus = reader.GetInt64(1),
              ThreePlus = reader.GetInt64(2),
              TotalOrders = reader.GetInt64(3)
            };
          }
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36getnewcustomeranalytics error: {e.Message}");
        throw;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }

      return result;
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public List<ReviewAnalyticsRow> ds36getreviewanalytics(long reviewid_baseline, ref double rt)
    {
      var result = new List<ReviewAnalyticsRow>();
      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        Get_Review_Analytics.Parameters["reviewid_baseline"].Value = reviewid_baseline;

        using (NpgsqlDataReader reader = Get_Review_Analytics.ExecuteReader())
        {
          while (reader.Read())
          {
            result.Add(new ReviewAnalyticsRow
            {
              Stars = reader.GetInt32(0),
              Reviews = reader.GetInt64(1),
              Added = reader.GetInt64(2),
              AvgHelp = reader.GetDecimal(3),
              HighHelp = reader.GetInt64(4),
              LowHelp = reader.GetInt64(5)
            });
          }
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36getreviewanalytics error: {e.Message}");
        throw;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }

      return result;
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public PricePointAnalyticsData ds36getpricepointanalytics(long baseline_product_count, ref double rt)
    {
      var result = new PricePointAnalyticsData
      {
        PricePoints = new List<PricePointAnalyticsRow>()
      };
      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        Get_Price_Point_Analytics.Parameters["baseline_product_count"].Value = baseline_product_count;

        using (NpgsqlDataReader reader = Get_Price_Point_Analytics.ExecuteReader())
        {
          // PostgreSQL returns combined rows: price distribution rows + final row with new products count
          while (reader.Read())
          {
            string priceEnding = reader.GetString(0);
            long productCount = reader.GetInt64(1);
            long newProductsPurchased = reader.GetInt64(2);

            // Price distribution rows have productCount > 0
            // Final row has productCount = 0 and newProductsPurchased value
            if (productCount > 0)
            {
              result.PricePoints.Add(new PricePointAnalyticsRow
              {
                PriceEnding = priceEnding,
                ProductCount = productCount
              });
            }
            else
            {
              result.NewProductsPurchased = newProductsPurchased;
            }
          }
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36getpricepointanalytics error: {e.Message}");
        throw;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }

      return result;
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public InventoryAnalyticsRow ds36getinventoryanalytics(ref double rt)
    {
      InventoryAnalyticsRow result = null;
      Stopwatch timer = Stopwatch.StartNew();

      try
      {
        using (NpgsqlDataReader reader = Get_Inventory_Analytics.ExecuteReader())
        {
          if (reader.Read())
          {
            result = new InventoryAnalyticsRow
            {
              LowStockCount = reader.GetInt64(0),
              HighStockCount = reader.GetInt64(1),
              ReorderCount = reader.GetInt64(2),
              AvgInventory = reader.GetDecimal(3),
              DeadStock = reader.GetInt64(4),
              LowSales = reader.GetInt64(5),
              MedSales = reader.GetInt64(6),
              HighSales = reader.GetInt64(7),
              TotalProducts = reader.GetInt64(8)
            };
          }
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds36getinventoryanalytics error: {e.Message}");
        throw;
      }
      finally
      {
        rt = timer.Elapsed.TotalSeconds;
      }

      return result;
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public long ds2getrowcount(string tablename)
    {
      long count = 0;
      try
      {
        // PostgreSQL: products1 (lowercase, public schema)
        string pgsqlTable = tablename.ToLower();
        using (NpgsqlCommand cmd = new NpgsqlCommand($"SELECT COUNT(*) FROM {pgsqlTable}", objConn))
        {
          count = Convert.ToInt64(cmd.ExecuteScalar());
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds2getrowcount({tablename}) error: {e.Message}");
        throw;
      }
      return count;
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public long ds2getmaxid(string tablename, string columnname)
    {
      long maxid = 0;
      try
      {
        // PostgreSQL: reviews1 (lowercase), review_id (lowercase)
        string pgsqlTable = tablename.ToLower();
        string pgsqlColumn = columnname.ToLower();
        using (NpgsqlCommand cmd = new NpgsqlCommand($"SELECT COALESCE(MAX({pgsqlColumn}), 0) FROM {pgsqlTable}", objConn))
        {
          maxid = Convert.ToInt64(cmd.ExecuteScalar());
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Thread {Thread.CurrentThread.Name}: ds2getmaxid({tablename}, {columnname}) error: {e.Message}");
        throw;
      }
      return maxid;
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public static string GetDatabaseType()
    {
      return "pgsql";
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public void ds2validate(string outputFile, string targetServer, int storeNumber)
    {
      string sqlFilePath = $"validate/{targetServer}/pgsql_validate_post_test{storeNumber}.sql";
      if (!File.Exists(sqlFilePath))
      {
        Console.WriteLine($"Error: Validation SQL file not found: {sqlFilePath}");
        Console.WriteLine("Please run the Perl generation script first:");
        Console.WriteLine($"  perl pgsql_ds_perl_validate_multi.pl {targetServer} {storeNumber} post_test generate");
        return;
      }

      string sqlContent = File.ReadAllText(sqlFilePath);

      // Filter out psql-specific commands (\c, \timing, etc.)
      var filteredLines = new List<string>();
      foreach (string line in sqlContent.Split(new[] { '\r', '\n' }, StringSplitOptions.None))
      {
        string trimmed = line.TrimStart();
        // Skip psql meta-commands
        if (trimmed.StartsWith("\\"))
        {
          continue;
        }
        filteredLines.Add(line);
      }
      sqlContent = string.Join("\n", filteredLines);

      // Set up NOTICE event handler to capture RAISE NOTICE output
      var noticeMessages = new List<string>();
      objConn.Notice += (sender, e) =>
      {
        noticeMessages.Add(e.Notice.MessageText);
      };

      try
      {
        // Execute entire script (PostgreSQL handles multiple statements)
        using (NpgsqlCommand cmd = new NpgsqlCommand(sqlContent, objConn))
        {
          cmd.CommandTimeout = 600; // 10 minutes for validation queries

          // Execute and capture result sets
          using (NpgsqlDataReader reader = cmd.ExecuteReader())
          {
            using (StreamWriter writer = new StreamWriter(outputFile, append: true))
            {
              do
              {
                // Write any NOTICE messages collected before this result set
                foreach (string notice in noticeMessages)
                {
                  writer.WriteLine(notice);
                }
                noticeMessages.Clear();

                // Check if this result set has rows
                if (reader.HasRows)
                {
                  // Write column headers with type-aware padding
                  List<string> headers = new List<string>();
                  for (int i = 0; i < reader.FieldCount; i++)
                  {
                    string colName = reader.GetName(i);
                    Type fieldType = reader.GetFieldType(i);
                    // Numeric types get 15 chars (right-aligned), strings get 30 chars (left-aligned)
                    if (fieldType == typeof(int) || fieldType == typeof(long) ||
                        fieldType == typeof(decimal) || fieldType == typeof(double) ||
                        fieldType == typeof(float) || fieldType == typeof(short) ||
                        fieldType == typeof(byte))
                    {
                      headers.Add(colName.PadLeft(15));
                    }
                    else
                    {
                      headers.Add(colName.PadRight(30));
                    }
                  }
                  writer.WriteLine(string.Join(" ", headers));

                  // Write data rows with type-aware padding
                  while (reader.Read())
                  {
                    List<string> rowValues = new List<string>();
                    for (int i = 0; i < reader.FieldCount; i++)
                    {
                      string value = reader.IsDBNull(i) ? "" : reader.GetValue(i).ToString() ?? "";
                      Type fieldType = reader.GetFieldType(i);
                      // Numeric types get 15 chars (right-aligned), strings get 30 chars (left-aligned)
                      if (fieldType == typeof(int) || fieldType == typeof(long) ||
                          fieldType == typeof(decimal) || fieldType == typeof(double) ||
                          fieldType == typeof(float) || fieldType == typeof(short) ||
                          fieldType == typeof(byte))
                      {
                        rowValues.Add(value.PadLeft(15));
                      }
                      else
                      {
                        rowValues.Add(value.PadRight(30));
                      }
                    }
                    writer.WriteLine(string.Join(" ", rowValues));
                  }
                  writer.WriteLine();
                }
              } while (reader.NextResult());

              // Write any remaining NOTICE messages
              foreach (string notice in noticeMessages)
              {
                writer.WriteLine(notice);
              }
            }
          }
        }
      }
      catch (Exception e)
      {
        Console.WriteLine($"Error executing validation SQL: {e.Message}");
      }
      finally
      {
        // Remove event handler
        objConn.Notice -= (sender, e) => { };
      }
    }

    //
    //-------------------------------------------------------------------------------------------------
    //
    public bool ds2close()
    {
      if (objConn != null && objConn.State == ConnectionState.Open)
      {
        objConn.Close();
      }
      return (true);
    } // end ds2close()
  } // end Class ds2Interface
} // end namespace ds2xdriver


